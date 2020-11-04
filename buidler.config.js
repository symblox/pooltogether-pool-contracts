const networks = require('./buidler.networks')

const { TASK_COMPILE_GET_COMPILER_INPUT } = require('@nomiclabs/buidler/builtin-tasks/task-names')

const RNGBlockhashRopsten = require('@pooltogether/pooltogether-rng-contracts/deployments/ropsten/RNGBlockhash.json')
const RNGBlockhashRinkeby = require('@pooltogether/pooltogether-rng-contracts/deployments/rinkeby/RNGBlockhash.json')
const RNGBlockhashKovan = require('@pooltogether/pooltogether-rng-contracts/deployments/kovan/RNGBlockhash.json')
const RNGBlockhashVlxTest = require('@symblox/pooltogether-rng-contracts/deployments/vlxtest/RNGBlockhash.json')

usePlugin('@nomiclabs/buidler-waffle')
usePlugin('buidler-gas-reporter')
usePlugin('solidity-coverage')
usePlugin('@nomiclabs/buidler-etherscan')
usePlugin('buidler-deploy')

// This must occur after buidler-deploy!
task(TASK_COMPILE_GET_COMPILER_INPUT).setAction(async (_, __, runSuper) => {
  const input = await runSuper()
  input.settings.metadata.useLiteralContent = process.env.USE_LITERAL_CONTENT != 'false'
  console.log(`useLiteralContent: ${input.settings.metadata.useLiteralContent}`)
  return input
})

task('accounts', 'Prints the list of accounts', async () => {
  const walletMnemonic = ethers.Wallet.fromMnemonic(process.env.HDWALLET_MNEMONIC)
  console.log(walletMnemonic.address)
})

// task('balance', "Prints an account's balance")
//   .addParam('account', "The account's address")
//   .setAction(async taskArgs => {
//     const provider = new ethers.providers.JsonRpcProvider()
//     const walletMnemonic = ethers.Wallet.fromMnemonic(process.env.HDWALLET_MNEMONIC)
//     console.log(walletMnemonic.address)
//     const wallet = walletMnemonic.connect(provider)
//     const balance = await wallet.getBalance()

//     console.log(ethers.utils.parseEther(balance), 'ETH')
//   })

const testnetAdmin = '0xFC32E7c7c55391ebb4F91187c91418bF96860cA9' // Account 1
const testnetUser1 = '0xFC32E7c7c55391ebb4F91187c91418bF96860cA9' // Account 3
const testnetUser2 = '0xFC32E7c7c55391ebb4F91187c91418bF96860cA9' // Account 4
const testnetUser3 = '0xFC32E7c7c55391ebb4F91187c91418bF96860cA9' // Account 5

const optimizerEnabled = !process.env.OPTIMIZER_DISABLED

const config = {
  solc: {
    version: '0.6.12',
    optimizer: {
      enabled: optimizerEnabled,
      runs: 200
    },
    evmVersion: 'istanbul'
  },
  paths: {
    artifacts: './build'
  },
  networks,
  gasReporter: {
    currency: 'CHF',
    gasPrice: 21,
    enabled: process.env.REPORT_GAS ? true : false
  },
  namedAccounts: {
    deployer: {
      default: 0
    },
    trustedForwarder: {
      42: '0x0842Ad6B8cb64364761C7c170D0002CC56b1c498',
      4: '0x956868751Cc565507B3B58E53a6f9f41B56bed74',
      3: '0x25CEd1955423BA34332Ec1B60154967750a0297D',
      1: '0xa530F85085C6FE2f866E7FdB716849714a89f4CD'
    },
    rng: {
      111: RNGBlockhashVlxTest.address,
      42: RNGBlockhashKovan.address,
      4: RNGBlockhashRinkeby.address,
      3: RNGBlockhashRopsten.address
    },
    adminAccount: {
      42: testnetAdmin,
      4: testnetAdmin,
      3: testnetAdmin
    },
    testnetUser1: {
      default: testnetUser1,
      3: testnetUser1,
      4: testnetUser1,
      42: testnetUser1
    },
    testnetUser2: {
      default: testnetUser2,
      3: testnetUser2,
      4: testnetUser2,
      42: testnetUser2
    },
    testnetUser3: {
      default: testnetUser3,
      3: testnetUser3,
      4: testnetUser3,
      42: testnetUser3
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  analytics: {
    enabled: false
  }
}

module.exports = config
