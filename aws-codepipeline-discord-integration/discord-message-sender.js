const discord_webhook_url = process.env.DISCORD_WEBHOOK_URL
const axios = require('axios')

module.exports.postMessage = (message) => {
  axios({
    method: 'post',
    headers: {
      'Content-Type': 'application/json'
    },
    url: discord_webhook_url,
    data: message
  });
}