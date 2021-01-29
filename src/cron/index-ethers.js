const ethers = require('ethers')
const srcDir = require('find-config')('src')
const { NonceManager } = require('@ethersproject/experimental')
const sleep = require('util').promisify(setTimeout)
const { readMnemonic } = require(srcDir + '/keyman')
const db = require(srcDir + '/db')

require('dotenv').config({ path: require('find-config')('.env') })

const network = 'kovan'
const infuraId =  process.env.INFURA_API_KEY

const defaultPath = "m/44'/60'/0'/0/0"
const currentPath = "m/44'/60'/0'/0/1"

//const pollAddr = '0x9Af7eC6B510794802bb19a65a7FF24e0B9350828'
const pollAddr = '0xA43455c00D5ABaED8d257451d73c40718E8b48BD'
const pollAbi = [{"inputs":[],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"pollId","type":"uint256"},{"indexed":true,"internalType":"address","name":"bettor","type":"address"},{"indexed":false,"internalType":"uint256","name":"index","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"amount","type":"uint256"},{"indexed":false,"internalType":"uint32","name":"totalBetCount","type":"uint32"},{"indexed":false,"internalType":"uint32","name":"totalBetAmount","type":"uint32"}],"name":"BetCreated","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"pollId","type":"uint256"},{"indexed":true,"internalType":"address","name":"creator","type":"address"},{"indexed":false,"internalType":"uint32","name":"startTime","type":"uint32"},{"indexed":false,"internalType":"uint32","name":"duration","type":"uint32"},{"indexed":false,"internalType":"uint8","name":"mode","type":"uint8"}],"name":"PollCreated","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"pollId","type":"uint256"},{"indexed":true,"internalType":"address","name":"bettor","type":"address"},{"indexed":false,"internalType":"uint256","name":"amount","type":"uint256"},{"indexed":false,"internalType":"uint8","name":"payType","type":"uint8"}],"name":"PollPaid","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"pollId","type":"uint256"}],"name":"PollRevealed","type":"event"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"}],"name":"bets","outputs":[{"internalType":"uint8","name":"choiceDecoded","type":"uint8"},{"internalType":"address","name":"bettor","type":"address"},{"internalType":"uint32","name":"betAmount","type":"uint32"},{"internalType":"uint32","name":"paidAmount","type":"uint32"},{"internalType":"bytes32","name":"choiceHash","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint32","name":"_startTime","type":"uint32"},{"internalType":"uint32","name":"_duration","type":"uint32"},{"internalType":"string","name":"_question","type":"string"},{"internalType":"string[]","name":"_choices","type":"string[]"},{"internalType":"uint8","name":"_mode","type":"uint8"}],"name":"createPoll","outputs":[{"internalType":"uint256","name":"pollId","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"deployedBlock","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"gameInfo","outputs":[{"internalType":"uint16","name":"totalPollCount","type":"uint16"},{"internalType":"uint32","name":"totalBetCount","type":"uint32"},{"internalType":"uint32","name":"totalBetAmount","type":"uint32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"gameRule","outputs":[{"internalType":"uint8","name":"operatorCommission","type":"uint8"},{"internalType":"uint8","name":"creatorCommission","type":"uint8"},{"internalType":"uint8","name":"maxChoiceCount","type":"uint8"},{"internalType":"uint16","name":"maxBetCount","type":"uint16"},{"internalType":"uint32","name":"minBetAmount","type":"uint32"},{"internalType":"uint32","name":"maxBetAmount","type":"uint32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint8","name":"_choice","type":"uint8"},{"internalType":"address","name":"_addr","type":"address"},{"internalType":"bytes32","name":"_secreteSalt","type":"bytes32"}],"name":"getHash","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"pure","type":"function"},{"inputs":[{"internalType":"uint256","name":"_pollId","type":"uint256"}],"name":"getPollChoices","outputs":[{"internalType":"string[]","name":"","type":"string[]"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getPollCount","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_pollId","type":"uint256"}],"name":"getStatus","outputs":[{"internalType":"enum BlindPollBet.Status","name":"","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_pollId","type":"uint256"}],"name":"isActive","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_pollId","type":"uint256"}],"name":"isFinished","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_pollId","type":"uint256"}],"name":"isPaid","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_pollId","type":"uint256"},{"internalType":"bytes32","name":"_secreteSalt","type":"bytes32"}],"name":"payPoll","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_pollId","type":"uint256"},{"internalType":"bytes32","name":"_choiceHash","type":"bytes32"},{"internalType":"uint32","name":"_betAmount","type":"uint32"}],"name":"pollBet","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"}],"name":"pollChoices","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"pollDetails","outputs":[{"internalType":"bool","name":"isPaid","type":"bool"},{"internalType":"bool","name":"isTerminated","type":"bool"},{"internalType":"uint16","name":"betCount","type":"uint16"},{"internalType":"uint32","name":"totalAmount","type":"uint32"},{"internalType":"bytes32","name":"secretSalt","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint8","name":"","type":"uint8"}],"name":"pollResults","outputs":[{"internalType":"uint32","name":"","type":"uint32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"polls","outputs":[{"internalType":"uint8","name":"choiceCount","type":"uint8"},{"internalType":"uint8","name":"mode","type":"uint8"},{"internalType":"address","name":"creator","type":"address"},{"internalType":"uint32","name":"startTime","type":"uint32"},{"internalType":"uint32","name":"duration","type":"uint32"},{"internalType":"string","name":"question","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint32","name":"_val","type":"uint32"}],"name":"setMaxBetAmount","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint16","name":"_val","type":"uint16"}],"name":"setMaxBetCount","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint32","name":"_val","type":"uint32"}],"name":"setMinBetAmount","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bool","name":"_val","type":"bool"}],"name":"setNewPollAllow","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_pollId","type":"uint256"}],"name":"terminatePoll","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"tokenAddress","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_tokenAddr","type":"address"}],"name":"updateToken","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint8","name":"","type":"uint8"}],"name":"winningChoices","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_toAddr","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"withdrawTo","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}]


let provider
let wallet
let pollContract

const getContract = async () => {
  provider = new ethers.providers.InfuraProvider.getWebSocketProvider(network, infuraId)
  //provider = new ethers.providers.InfuraProvider(network, infuraId)
  let  rawWallet = ethers.Wallet.fromMnemonic(readMnemonic(), currentPath)
  wallet = rawWallet.connect(provider)
  pollContract = new ethers.Contract(pollAddr, pollAbi, wallet)
  return provider, wallet, pollContract
}

(async () => {
  try {
    await getContract()
  } catch (err) {
  }
})();


const payPoll = async (pollId, contract) => {

  const dbKey = `saltHash-${pollId}`
  const secretSalt = db.get(dbKey) || "0x3078300000000000000000000000000000000000000000000000000000000000"
  try {
    let r = await contract.payPoll(pollId, secretSalt)
    return r
  } catch(err) {
    let errorPolls = new Set(db.get('polls-error') || [])
    errorPolls.add(pollId)
    db.put('polls-error', Array.from(errorPolls.values()))
    console.log(err)
  }
} 

const dbReset = () => {
  db.put('last-block', 1)
  db.put('polls-pending', [])
}

const downloadPolls = async (startBlock) => {
  if (!startBlock) startBlock = db.get('last-block')
  if (!startBlock) startBlock = (await pollContract.deployedBlock()).toNumber()
  let endBlock = await provider.getBlockNumber()
  let pollsPending = new Set(db.get('polls-pending') || [])
  let polls = await pollContract.queryFilter('PollCreated', startBlock, endBlock)
  polls.forEach(poll => {
    let pollId = poll.args.pollId.toString()
    let startTime = poll.args.startTime
    let endTime = startTime + poll.args.duration
    let creator = poll.args.creator
    let mode = poll.args.mode
    let pollKey = 'poll-' + pollId
    db.put(pollKey, { pollId, startTime, endTime, creator, mode })
    pollsPending.add(pollId)
  })
  pendingList = Array.from(pollsPending.values())
  db.put('polls-pending', pendingList)
  db.put('last-block', endBlock)
  return pendingList
}

let pollWalletNonce 
let managedSigner = new NonceManager(wallet)
let bulkContract = pollContract.connect(managedSigner)
const batchPayPoll = async () => {
  await getContract()
  let pendingList = await downloadPolls()
  newPending = []
  pendingList.forEach(async pollId => {
    await sleep(2000)
    let now = parseInt(Date.now()/1000)
    let poll = db.get(`poll-${pollId}`)
    if (poll.endTime < now) {
      let pd = await bulkContract.pollDetails(pollId)
      if (pd.isPaid || pd.isTerminated) {
        console.log(`PollId ${pollId} is already processed...`)
      } else {
        console.log(`processing ${poll.pollId}...`)
        try {
          r = await payPoll(poll.pollId, bulkContract)
          console.log(`pollId: ${pollId}, nonce: ${r.nonce}, txid: ${r.hash}`)
          console.log(r)
        } catch(err) {
          console.log(err)
        }
      }
    } else {
      newPending.push(pollId)
    }
  })
  
  db.put('polls-pending', newPending)  
  return newPending
}

module.exports = { batchPayPoll, downloadPolls, payPoll, provider, wallet, pollContract }