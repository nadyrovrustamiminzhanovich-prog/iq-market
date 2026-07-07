const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");
const fs = require("fs");

console.log('1. Importing done. Loading rules...');
const rulesContent = fs.readFileSync("firestore.rules", "utf8");
console.log('2. Rules loaded. Initializing test environment on localhost:8080...');

initializeTestEnvironment({
  projectId: "iq-market-3dc07",
  firestore: {
    rules: rulesContent,
    host: "localhost",
    port: 8080,
  },
}).then((testEnv) => {
  console.log('3. Success! Test environment initialized.');
  testEnv.cleanup().then(() => {
    console.log('4. Cleanup done.');
    process.exit(0);
  });
}).catch((e) => {
  console.error('Failed to initialize:', e);
  process.exit(1);
});
