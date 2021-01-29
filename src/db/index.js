const fs = require('fs');
const lmdb = require('node-lmdb')
const dbName = "poll"
let storage = require('find-config')('storage')

//const level = require('level-rocksdb')
//const storage = __dirname + '/../../storage/'
//const db = level(storage, { valueEncoding: 'json' })

class db {
  static init() {
    var env = new lmdb.Env()
    env.open({path: storage})
    env.close()
  }

  static get(key) {
    var env = new lmdb.Env({ readonly: true })
    env.open({path: storage})
    const pollDb = env.openDbi({ name: dbName, create:true })
    const txn = env.beginTxn()
    const data = txn.getString(pollDb, key)
    txn.commit()
    env.close()
    return JSON.parse(data)
  }

  static put(key, data) {
    var env = new lmdb.Env();
    env.open({path: storage})
    const pollDb = env.openDbi({ name: dbName, create:true })
    const txn = env.beginTxn()
    const rtn = txn.putString(pollDb, key, JSON.stringify(data))
    txn.commit()
    env.close()
    return rtn
  }
}

if (!fs.existsSync(storage)){
  fs.mkdirSync('./storage')
  storage = require('find-config')('storage')
  db.init()
}

db.get('test')


module.exports = db
