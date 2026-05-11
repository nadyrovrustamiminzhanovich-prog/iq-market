const { google } = require('googleapis');
const auth = new google.auth.GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/cloud-platform']
});

async function makePublic() {
  const client = await auth.getClient();
  const projectId = 'iq-market-3dc07';
  const region = 'us-central1';
  const functionName = 'telegramWebhook';
  
  const cloudfunctions = google.cloudfunctions({
    version: 'v1',
    auth: client
  });

  const resource = `projects/${projectId}/locations/${region}/functions/${functionName}`;

  try {
    console.log(`Setting IAM policy for ${resource}...`);
    const response = await cloudfunctions.projects.locations.functions.setIamPolicy({
      resource,
      requestBody: {
        policy: {
          bindings: [
            {
              role: 'roles/cloudfunctions.invoker',
              members: ['allUsers']
            }
          ]
        }
      }
    });
    console.log('Success! Function is now public.');
    console.log(JSON.stringify(response.data, null, 2));
  } catch (err) {
    console.error('Error setting IAM policy:', err.message);
    if (err.response) {
      console.error(JSON.stringify(err.response.data, null, 2));
    }
  }
}

makePublic();
