const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

function getArg(name, index) {
  const value = process.argv[index];
  if (!value || value.trim() === "") {
    console.error(`Missing ${name}.`);
    process.exit(1);
  }
  return value.trim();
}

function loadServiceAccount() {
  const rawPath =
    process.env.FIREBASE_SERVICE_ACCOUNT ||
    process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!rawPath) {
    console.error(
      "Set FIREBASE_SERVICE_ACCOUNT (or GOOGLE_APPLICATION_CREDENTIALS) to the service account JSON path."
    );
    process.exit(1);
  }
  const resolved = path.resolve(rawPath);
  if (!fs.existsSync(resolved)) {
    console.error(`Service account JSON not found: ${resolved}`);
    process.exit(1);
  }
  return require(resolved);
}

function csvEscape(value) {
  const raw = value == null ? "" : String(value);
  if (/[",\r\n]/.test(raw)) {
    return `"${raw.replace(/"/g, '""')}"`;
  }
  return raw;
}

function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") {
    return value.toDate();
  }
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : new Date(parsed);
  }
  if (typeof value === "number") {
    const millis = value > 10000000000 ? value : value * 1000;
    return new Date(millis);
  }
  return null;
}

async function run() {
  const articleId = getArg("article doc id", 2);
  const outputPath =
    process.argv[3] && process.argv[3].trim().length > 0
      ? process.argv[3].trim()
      : `comments_${articleId}.csv`;

  const serviceAccount = loadServiceAccount();
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  const firestore = admin.firestore();
  const snap = await firestore
    .collection("articles")
    .doc(articleId)
    .collection("comments")
    .get();

  const rows = snap.docs.map((doc) => {
    const data = doc.data() || {};
    const createdRaw = data.createdAt || data.createdAtClient;
    const createdAt = toDate(createdRaw);
    return {
      commentId: doc.id,
      articleId: data.articleId || articleId,
      authorUid: data.authorUid || "",
      authorName: data.authorName || "",
      visibleTo: data.visibleTo || "",
      createdAt: createdAt ? createdAt.toISOString() : "",
      text: data.text || "",
    };
  });

  rows.sort((a, b) => {
    const aTime = a.createdAt ? Date.parse(a.createdAt) : 0;
    const bTime = b.createdAt ? Date.parse(b.createdAt) : 0;
    return aTime - bTime;
  });

  const header = [
    "commentId",
    "articleId",
    "authorUid",
    "authorName",
    "visibleTo",
    "createdAt",
    "text",
  ];
  const lines = [header.join(",")];
  for (const row of rows) {
    lines.push(
      [
        row.commentId,
        row.articleId,
        row.authorUid,
        row.authorName,
        row.visibleTo,
        row.createdAt,
        row.text,
      ]
        .map(csvEscape)
        .join(",")
    );
  }

  const resolvedOut = path.resolve(outputPath);
  fs.writeFileSync(resolvedOut, lines.join("\n"), "utf8");
  console.log(`Exported ${rows.length} comments to ${resolvedOut}`);
}

run().catch((err) => {
  console.error("Export failed:", err);
  process.exit(1);
});
