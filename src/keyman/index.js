const { JWKS, JWE } = require('jose')
const updateDotenv = require('update-dotenv')
require('dotenv').config({ path: require('find-config')('.env') })

//process.env.INFURA_API_KEY
//process.env.MNEMONIC_ENC

let keyStore 

if (process.env.KEY_STORE) {
  keyStore = JWKS.asKeyStore(JSON.parse(process.env.KEY_STORE))
} else {
  keyStore = new JWKS.KeyStore()
  keyStore.generateSync('RSA', 2048, {kid: 'encrypt'})
  updateDotenv({KEY_STORE: JSON.stringify(keyStore.toJWKS(true))})
}

const saveMnemonic = (mnemonic) => {
  const key = keyStore.get({ kid: 'encrypt' })
  const encyptedTxt = JWE.encrypt(mnemonic, key)
  updateDotenv({MNEMONIC_ENC: encyptedTxt})
  return encyptedTxt
}

const readMnemonic = () => {
  const encryptedTxt = process.env.MNEMONIC_ENC
  const key = keyStore.get({ kid: 'encrypt' })
  return JWE.decrypt(encryptedTxt, key).toString()
}

module.exports = { saveMnemonic, readMnemonic, keyStore }

