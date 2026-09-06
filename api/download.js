// Vercel serverless entry. The implementation lives in Website/api so the
// static build (Website/build.py, run from the repo root) and the functions
// share one source tree. Deploying from the repo root means Vercel only scans
// <root>/api for functions, so each route re-exports its Website/api handler.
module.exports = require("../Website/api/download.js");
