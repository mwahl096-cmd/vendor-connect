/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import { setGlobalOptions } from "firebase-functions/v2/options";
import { onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";

admin.initializeApp();
// Avoid Firestore rejecting undefined fields
try {
  admin.firestore().settings({ ignoreUndefinedProperties: true });
} catch (_) {
  // settings can only be set once; ignore if already set
}

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Send FCM to topic when a new article is created
export const onArticleCreated = onDocumentCreated(
  "articles/{articleId}",
  async (event) => {
    try {
      const data = event.data?.data();
      if (!data) return;
      const source = data.__source ?? "unknown";
      logger.info("Article created", {
        id: event.params.articleId,
        source,
      });
    } catch (e) {
      logger.error("Failed to send notification", e as any);
    }
  }
);

// Simple WordPress webhook to create an article document from WP payload
// Helper to fetch JSON via https (Node built-in), avoids depending on fetch types
import * as https from "https";
function fetchJson(url: string): Promise<any> {
  return new Promise((resolve, reject) => {
    https
      .get(url, (resp) => {
        let data = "";
        resp.on("data", (chunk) => (data += chunk));
        resp.on("end", () => {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(e);
          }
        });
      })
      .on("error", reject);
  });
}

function fetchText(url: string): Promise<string> {
  return new Promise((resolve, reject) => {
    https
      .get(url, (resp) => {
        let data = "";
        resp.on("data", (chunk) => (data += chunk));
        resp.on("end", () => resolve(data));
      })
      .on("error", reject);
  });
}

const WP_BASE = process.env.WP_BASE_URL || "https://vendorconnectapp.com";

export const wpWebhook = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }
  try {
    const body = req.body || {};
    // Try to locate the WordPress post ID from various free-plugin payload shapes
    const wpIdRaw =
      body.id ??
      body.ID ??
      body.post_id ??
      body.postId ??
      body.post_ID ??
      body.post?.ID ??
      body.post?.id ??
      body?.data?.post_id ??
      body?.data?.post?.ID ??
      body?.data?.post?.id ??
      body?.data?.ID ??
      body?.data?.id;
    const wpId = Number(wpIdRaw || 0);
    if (!wpId || Number.isNaN(wpId)) {
      res.status(400).json({ ok: false, error: "Missing post id" });
      return;
    }

    // Prefer embedded payload, otherwise fetch full post from WP REST for enrichment
    let source: any = body;
    const hasEmbedded = !!(source && (source._embedded || source.featured_media_url || source.categories || source.tags));
    if (!hasEmbedded || !source.title) {
      try {
        source = await fetchJson(`${WP_BASE}/wp-json/wp/v2/posts/${wpId}?_embed`);
      } catch (e) {
        logger.warn("Failed to fetch from WP REST, falling back to minimal payload", e as any);
      }
    }

    // Normalize fields
    const title = source?.title?.rendered ?? source?.title ?? body?.post?.post_title ?? "Untitled";
    const contentHtml = source?.content?.rendered ?? source?.content ?? body?.post?.post_content ?? "";
    const excerpt = source?.excerpt?.rendered ?? source?.excerpt ?? body?.post?.post_excerpt ?? "";
    const embeddedTerms = Array.isArray(source?._embedded?.["wp:term"]) ? source._embedded["wp:term"] : [];
    const catNames: string[] = Array.isArray(embeddedTerms[0])
      ? (embeddedTerms[0] as any[]).map((c: any) => c?.name).filter(Boolean)
      : Array.isArray(source?.categories)
      ? (source.categories as any[]).map((c: any) => String(c))
      : [];
    const tagNames: string[] = Array.isArray(embeddedTerms[1])
      ? (embeddedTerms[1] as any[]).map((t: any) => t?.name).filter(Boolean)
      : Array.isArray(source?.tags)
      ? (source.tags as any[]).map((t: any) => String(t))
      : [];
    let featuredImageUrl: string | undefined = Array.isArray(source?._embedded?.["wp:featuredmedia"]) && source._embedded["wp:featuredmedia"].length > 0
      ? source._embedded["wp:featuredmedia"][0]?.source_url
      : source?.featured_media_url || source?.jetpack_featured_media_url ||
        source?.better_featured_image?.source_url ||
        (Array.isArray(source?.yoast_head_json?.og_image) && source.yoast_head_json.og_image.length > 0
          ? source.yoast_head_json.og_image[0]?.url
          : undefined);

    // Fallback: fetch media by ID if available
    if ((!featuredImageUrl || featuredImageUrl.length === 0) && typeof source?.featured_media === "number" && source.featured_media > 0) {
      try {
        const media = await fetchJson(`${WP_BASE}/wp-json/wp/v2/media/${source.featured_media}`);
        if (media?.source_url) featuredImageUrl = String(media.source_url);
      } catch (e) {
        logger.warn("Failed to fetch media by ID", e as any);
      }
    }

    // Fallback: grab first <img> from contentHtml
    if ((!featuredImageUrl || featuredImageUrl.length === 0) && (contentHtml || "").length > 0) {
      const match = /<img[^>]+src=["']([^"']+)["']/i.exec(String(contentHtml));
      if (match && match[1]) featuredImageUrl = match[1];
    }

    // Final fallback: scrape the public post page for og:image/twitter:image or first <img>
    if ((!featuredImageUrl || featuredImageUrl.length === 0) && typeof source?.link === "string") {
      try {
        const html = await fetchText(String(source.link));
        let m = /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i.exec(html);
        if (!m) m = /<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i.exec(html);
        if (!m) m = /<img[^>]+src=["']([^"']+)["']/i.exec(html);
        if (m && m[1]) featuredImageUrl = m[1];
      } catch (e) {
        logger.warn("Failed to scrape og:image", e as any);
      }
    }

    const publishedAtField = source?.date ? admin.firestore.Timestamp.fromDate(new Date(source.date)) : admin.firestore.FieldValue.serverTimestamp();

    const statusRaw =
      source?.status ??
      body?.status ??
      body?.post_status ??
      body?.postStatus ??
      "";

    const actionRaw = String(
      body?.action ??
        body?.event ??
        body?.hook ??
        body?.trigger ??
        body?.data?.action ??
        body?.data?.event ??
        ""
    )
      .toLowerCase()
      .trim();

    const explicitTrashStatuses = [
      String(body?.post_status ?? "").toLowerCase(),
      String(body?.postStatus ?? "").toLowerCase(),
      String(body?.status ?? "").toLowerCase(),
      String(body?.post?.post_status ?? "").toLowerCase(),
      String(body?.post?.status ?? "").toLowerCase(),
      String(body?.new_status ?? "").toLowerCase(),
      String(body?.old_status ?? "").toLowerCase(),
      String(body?.data?.status ?? "").toLowerCase(),
      String(body?.data?.post_status ?? "").toLowerCase(),
      String(body?.data?.new_status ?? "").toLowerCase(),
      String(body?.data?.old_status ?? "").toLowerCase(),
      String(body?.data?.previous_status ?? "").toLowerCase(),
      String(source?.status ?? "").toLowerCase(),
      String(statusRaw ?? "").toLowerCase(),
    ];

    const flaggedAsDelete =
      Boolean(body?.deleted ?? body?.is_deleted ?? body?.trashed) ||
      explicitTrashStatuses.some((s) => ["trash", "trashed", "deleted"].includes(s)) ||
      actionRaw.includes("trash") ||
      actionRaw.includes("delete") ||
      actionRaw.includes("remove");
    // Upsert by WordPress ID to avoid duplicates on update
    const ref = admin.firestore().collection("articles").doc(String(wpId));
    const previousSnap = await ref.get();
    const existed = previousSnap.exists;
    const previousStatus = String(previousSnap?.get("status") ?? "")
      .toLowerCase()
      .trim();

    let statusNormalized = String(statusRaw || "")
      .toLowerCase()
      .trim();
    if (flaggedAsDelete) {
      statusNormalized = "trash";
    }
    if (!statusNormalized && previousStatus && !flaggedAsDelete) {
      statusNormalized = previousStatus;
    }
    if (!statusNormalized) {
      statusNormalized = flaggedAsDelete ? "trash" : "unknown";
    }

    if (flaggedAsDelete && statusNormalized === "publish") {
      statusNormalized = "trash";
    }

    if (statusNormalized !== "publish") {
      if (existed) {
        await ref.delete();
        logger.info("Article deleted due to non-publish status", {
          id: ref.id,
          status: statusNormalized,
          previousStatus,
        });
      } else {
        logger.info("Skip creating article because status is not publish", {
          id: ref.id,
          status: statusNormalized,
        });
      }
      res.json({
        ok: true,
        id: ref.id,
        removed: existed,
        status: statusNormalized,
      });
      return;
    }

    const doc: Record<string, any> = {
      wpId: Number(wpId),
      title: String(title).replace(/<[^>]+>/g, ""),
      contentHtml: String(contentHtml),
      excerpt: String(excerpt).replace(/<[^>]+>/g, ""),
      categories: Array.isArray(catNames) ? catNames : [],
      tags: Array.isArray(tagNames) ? tagNames : [],
      allowComments: true,
      commentsVisibility: "public",
      publishedAt: publishedAtField,
      status: statusNormalized,
      __source: "wpWebhook",
    };
    if (typeof featuredImageUrl === "string" && featuredImageUrl.length > 0) {
      doc.featuredImageUrl = featuredImageUrl;
    }

    await ref.set(doc, { merge: true });
    try {
      await ref.update({
        __source: admin.firestore.FieldValue.delete(),
      });
    } catch (cleanupErr) {
      logger.debug("Failed to clear __source marker", cleanupErr as any);
    }

    const shouldNotify =
      statusNormalized === "publish" && previousStatus !== "publish";

    if (shouldNotify) {
      try {
        await admin.messaging().send({
          topic: "articles",
          notification: {
            title: doc.title || "New Article",
            body: doc.excerpt || "Tap to read",
          },
          data: {
            type: "article",
            articleId: ref.id,
          },
        });
        logger.info("Notification sent for article", {
          id: ref.id,
          existed,
          previousStatus,
        });
      } catch (err) {
        logger.error("Failed to send article notification", err as any);
      }
    } else {
      logger.info("Article webhook skipped notification", {
        id: ref.id,
        status: statusNormalized,
        previousStatus,
      });
    }

    res.json({ ok: true, id: ref.id, created: !existed });
  } catch (e) {
    logger.error("wpWebhook error", e as any);
    res.status(500).json({ ok: false });
  }
});

// Notify admins when a new vendor registers
export const onUserCreated = onDocumentCreated("users/{uid}", async (event) => {
  const data = event.data?.data();
  if (!data) return;
  try {
    await admin.messaging().send({
      topic: "articles-admins", // admins topic suffix
      notification: {
        title: "New Vendor Registration",
        body: `${data.name || data.email || "Vendor"} requested access`,
      },
      data: { type: "vendor_signup", uid: event.params.uid },
    });
  } catch (e) {
    logger.error("Failed to notify admins about new user", e as any);
  }
});

// Email user when approved switches from false -> true
export const onUserApproved = onDocumentUpdated("users/{uid}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return;
  const was = Boolean(before.approved);
  const now = Boolean(after.approved);
  if (was === false && now === true) {
    try {
      const email = after.email as string | undefined;
      if (!email) return;
      // Configure SMTP via env vars
      const host = process.env.SMTP_HOST;
      const port = Number(process.env.SMTP_PORT || 587);
      const user = process.env.SMTP_USER;
      const pass = process.env.SMTP_PASS;
      if (!host || !user || !pass) {
        logger.warn("SMTP not configured; skip approval email");
        return;
      }
      const transporter = nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user, pass },
      });
      await transporter.sendMail({
        from: `Vendor Connect <${user}>`,
        to: email,
        subject: "Your Vendor Connect account is approved",
        text: "Your account has been approved. You can now sign in to the app.",
        html: "<p>Your account has been <b>approved</b>. You can now sign in to the app.</p>",
      });
      logger.info("Sent approval email to", { email });
    } catch (e) {
      logger.error("Failed to send approval email", e as any);
    }
  }
});

// Callable to toggle vendor approval/disabled (server verified admin)
export const adminSetVendorFlags = onCall(async (req) => {
  const callerUid = req.auth?.uid;
  if (!callerUid) {
    throw new Error("Unauthenticated");
  }
  const callerDoc = await admin.firestore().doc(`users/${callerUid}`).get();
  if (!callerDoc.exists || callerDoc.get("role") !== "admin") {
    throw new Error("Forbidden");
  }
  const { uid, approved, disabled } = req.data as { uid: string; approved?: boolean; disabled?: boolean };
  if (!uid) throw new Error("uid required");
  const updates: Record<string, any> = {};
  if (typeof approved === "boolean") updates.approved = approved;
  if (typeof disabled === "boolean") updates.disabled = disabled;
  await admin.firestore().doc(`users/${uid}`).set(updates, { merge: true });
  return { ok: true };
});

