const ethers = require('ethers')

const networks = {
  buidlerevm: {
    blockGasLimit: 200000000,
    allowUnlimitedContractSize: true,
    chainId: 31337
  },
  coverage: {
    url: 'http://127.0.0.1:8555',
    blockGasLimit: 200000000,
    allowUnlimitedContractSize: true
  },
  localhost: {
    url: 'http://127.0.0.1:8545',
    blockGasLimit: 200000000,
    allowUnlimitedContractSize: true,
    chainId: 31337
  }
}

if (process.env.USE_BUIDLER_EVM_ACCOUNTS) {
  networks.buidlerevm.accounts = process.env.USE_BUIDLER_EVM_ACCOUNTS.split(/\s+/).map(privateKey => ({
    privateKey,
    balance: ethers.utils.parseEther('10000000').toHexString()
  }))
}

if (process.env.HDWALLET_MNEMONIC) {
  if (process.env.VELAS_TEST_RPC) {
    networks.vlxtest = {
      url: process.env.VELAS_TEST_RPC,
      accounts: {
        mnemonic: process.env.HDWALLET_MNEMONIC
      }
    }
  } else if (process.env.VELAS_RPC) {
    networks.vlxmain = {
      url: process.env.VELAS_RPC,
      accounts: {
        mnemonic: process.env.HDWALLET_MNEMONIC
      }
    }
  } else if (process.env.INFURA_API_KEY) {
    networks.kovan = {
      url: `https://kovan.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: {
        mnemonic: process.env.HDWALLET_MNEMONIC
      }
    }

    networks.ropsten = {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: {
        mnemonic: process.env.HDWALLET_MNEMONIC
      }
    }

    networks.rinkeby = {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: {
        mnemonic: process.env.HDWALLET_MNEMONIC
      }
    }

    networks.mainnet = {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: {
        mnemonic: process.env.HDWALLET_MNEMONIC
      }
    }
  } else {
    networks.fork = {
      url: 'http://127.0.0.1:8545'
    }
  }
} else {
  console.warn('No infura or hdwallet available for testnets')
}

module.exports = networks
