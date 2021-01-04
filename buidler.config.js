const networks = require("./buidler.networks")

const { TASK_COMPILE_GET_COMPILER_INPUT } = require("@nomiclabs/buidler/builtin-tasks/task-names")

const RNGBlockhashRopsten = require("@symblox/pvlx-rng-contracts/deployments/ropsten/RNGBlockhash.json")
const RNGBlockhashRinkeby = require("@symblox/pvlx-rng-contracts/deployments/rinkeby/RNGBlockhash.json")
const RNGBlockhashKovan = require("@symblox/pvlx-rng-contracts/deployments/kovan/RNGBlockhash.json")
const RNGBlockhashVlxtest = require("@symblox/pvlx-rng-contracts/deployments/vlxtest/RNGBlockhash.json")
const RNGBlockhashVlxmain = require("@symblox/pvlx-rng-contracts/deployments/vlxmain/RNGBlockhash.json")

const ReserveVlxtest = require("./deployments/vlxtest/Reserve.json")
const ReserveVlxmain = require("./deployments/vlxmain/Reserve.json")

usePlugin("@nomiclabs/buidler-waffle")
usePlugin("buidler-gas-reporter")
usePlugin("solidity-coverage")
usePlugin("@nomiclabs/buidler-etherscan")
usePlugin("buidler-deploy")
// usePlugin("buidler-abi-exporter")
usePlugin("@openzeppelin/buidler-upgrades")

// This must occur after buidler-deploy!
task(TASK_COMPILE_GET_COMPILER_INPUT).setAction(async (_, __, runSuper) => {
  const input = await runSuper()
  input.settings.metadata.useLiteralContent = process.env.USE_LITERAL_CONTENT != "false"
  console.log(`useLiteralContent: ${input.settings.metadata.useLiteralContent}`)
  return input
})

task("accounts", "Prints the list of accounts", async () => {
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

const testnetAdmin = "0xFC32E7c7c55391ebb4F91187c91418bF96860cA9" // Account 1
const testnetUser1 = "0xFC32E7c7c55391ebb4F91187c91418bF96860cA9" // Account 3
const testnetUser2 = "0xFC32E7c7c55391ebb4F91187c91418bF96860cA9" // Account 4
const testnetUser3 = "0xFC32E7c7c55391ebb4F91187c91418bF96860cA9" // Account 5

const optimizerEnabled = !process.env.OPTIMIZER_DISABLED

const config = {
  solc: {
    version: "0.6.12",
    optimizer: {
      enabled: optimizerEnabled,
      runs: 200
    },
    evmVersion: "istanbul"
  },
  paths: {
    artifacts: "./build"
  },
  networks,
  gasReporter: {
    currency: "CHF",
    gasPrice: 21,
    enabled: process.env.REPORT_GAS ? true : false
  },
  namedAccounts: {
    deployer: {
      default: 0
    },
    comptroller: {
      1: "0x4027dE966127af5F015Ea1cfd6293a3583892668"
    },
    reserve: {
      1: "0x3e8b9901dBFE766d3FE44B36c180A1bca2B9A295",
      106: ReserveVlxmain.address,
      111: ReserveVlxtest.address
    },
    rng: {
      106: RNGBlockhashVlxmain.address,
      111: RNGBlockhashVlxtest.address,
      42: RNGBlockhashKovan.address,
      4: RNGBlockhashRinkeby.address,
      3: RNGBlockhashRopsten.address
    },
    syx: {
      106: "0x01Db6ACFA20562Ba835aE9F5085859580A0b1386",
      111: "0x28a6312D786e9d7a78637dD137AbeF5332F3b2Aa"
    },
    svlx: {
      106: "0xb800D28E0dbb6C3D66c1d386c0ac37C187211eAE",
      111: "0x6a63011a41Df162921E2eDF7f10fabb7C93F3FB0"
    },
    miningPool: {
      106: "0x7bD57dCA1C703E068F4A0A3Bc506612372eF7dC6",
      111: "0x3FBaf23119a999336bb9bB0744bcC6f60540B4B4"
    },
    rewardPool: {
      106: "0x9fCdD9eb40CaC90A5C385C9Ef37b48E847B178a3",
      111: "0x2c140E4561ef42c20B60E600CA52B86147858AC5"
    },
    rewardPoolId: {
      106: "0",
      111: "0"
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
  },
  mocha: {
    timeout: 30000
  },
  abiExporter: {
    path: "./abis",
    only: [
      "IERC20Upgradeable",
      "CTokenInterface",
      "PrizePool",
      "MultipleWinners",
      "SingleRandomWinner",
      "PeriodicPrizeStrategy",
      "CompoundPrizePool",
      "SyxPrizePool",
      "SyxSingleWinner",
      "Sponsor"
    ],
    clear: true
  }
}

module.exports = config
