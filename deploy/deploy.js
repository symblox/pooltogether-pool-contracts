const { deploy1820 } = require('deploy-eip-1820')

const debug = require('debug')('ptv3:deploy.js')

const chainName = chainId => {
  switch (chainId) {
    case 106:
      return 'VELAS'
    case 111:
      return 'VELAS (Test)'
    case 1:
      return 'Mainnet'
    case 3:
      return 'Ropsten'
    case 4:
      return 'Rinkeby'
    case 5:
      return 'Goerli'
    case 42:
      return 'Kovan'
    case 31337:
      return 'BuidlerEVM'
    default:
      return 'Unknown'
  }
}

module.exports = async buidler => {
  const { getNamedAccounts, deployments, getChainId, ethers } = buidler
  const { deploy } = deployments

  const harnessDisabled = !!process.env.DISABLE_HARNESS

  let { deployer, rng, trustedForwarder, adminAccount, comptroller, reserve } = await getNamedAccounts()
  debug(`  Deployer account: ${deployer}`)

  const chainId = parseInt(await getChainId(), 10)
  const isLocal = [1, 3, 4, 42, 106, 111].indexOf(chainId) == -1
  // 31337 is unit testing, 1337 is for coverage
  const isTestEnvironment = chainId === 31337 || chainId === 1337 || chainId === 111
  // const signer = await ethers.provider.getSigner(deployer)
  const [signer] = await ethers.getSigners()

  debug('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
  debug('PoolTogether Pool Contracts - Deploy Script')
  debug('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  const locus = isLocal ? 'local' : 'remote'
  debug(`  Deploying to Network: ${chainName(chainId)} (${locus})`)

  if (!adminAccount) {
    debug('  Using deployer as adminAccount;')
    adminAccount = signer._address
  }
  debug('\n  adminAccount:  ', adminAccount)

  await deploy1820(signer)

  if (chainId === 111 || chainId === 106) {
    debug('\n  Deploying TrustedForwarder...')
    const deployResult = await deploy('TrustedForwarder', {
      from: deployer,
      skipIfAlreadyDeployed: true
    })
    trustedForwarder = deployResult.address

    // Display Contract Addresses
    debug('\n  Velas Mock Contract Deployments;\n')
    debug('  - TrustedForwarder: ', trustedForwarder)
    debug('  - RNGService:       ', rng)
  }

  if (isLocal) {
    debug('\n  Deploying TrustedForwarder...')
    const deployResult = await deploy('TrustedForwarder', {
      from: deployer,
      skipIfAlreadyDeployed: true
    })
    trustedForwarder = deployResult.address

    debug('\n  Deploying RNGService...')
    const rngServiceMockResult = await deploy('RNGServiceMock', {
      from: deployer,
      skipIfAlreadyDeployed: true
    })
    rng = rngServiceMockResult.address

    debug('\n  Deploying WVLX...')
    const wvlxResult = await deploy('WVLX', {
      args: [],
      contract: 'WVLX',
      from: deployer,
      skipIfAlreadyDeployed: true
    })

    debug('\n  Deploying syx...')
    const syxResult = await deploy('mockToken', {
      args: [],
      contract: 'mockToken',
      from: deployer,
      skipIfAlreadyDeployed: true
    })

    debug('\n  Deploying Dai...')
    const daiResult = await deploy('Dai', {
      args: ['DAI Test Token', 'DAI'],
      contract: 'ERC20Mintable',
      from: deployer,
      skipIfAlreadyDeployed: true
    })

    debug('\n  Deploying bpt...')
    const bptResult = await deploy('mockBpt', {
      args: [],
      contract: 'mockBpt',
      from: deployer,
      skipIfAlreadyDeployed: true
    })

    debug('\n  Deploying reward pool...')
    const rewardPoolResult = await deploy('mockRewardPool', {
      args: [],
      contract: 'mockRewardPool',
      from: deployer,
      skipIfAlreadyDeployed: true
    })
    const rewardPoolContract = await buidler.ethers.getContractAt('mockRewardPool', rewardPoolResult.address, signer)
    const syxContract = await buidler.ethers.getContractAt('mockToken', syxResult.address, signer)
   
    await rewardPoolContract.setSyx(syxResult.address)
    await syxContract.mint(rewardPoolResult.address, "100000000000000000000000")

    debug('\n  Deploying cDai...')
    // should be about 20% APR
    let supplyRate = '8888888888888'
    await deploy('cDai', {
      args: [daiResult.address, supplyRate],
      contract: 'CTokenMock',
      from: deployer,
      skipIfAlreadyDeployed: true
    })

    await deploy('yDai', {
      args: [daiResult.address],
      contract: 'yVaultMock',
      from: deployer,
      skipIfAlreadyDeployed: true
    })

    // Display Contract Addresses
    debug('\n  Local Contract Deployments;\n')
    debug('  - TrustedForwarder: ', trustedForwarder)
    debug('  - RNGService:       ', rng)
    debug('  - Dai:              ', daiResult.address)
    debug('  - WVLX:             ', wvlxResult.address)
    debug('  - SYX:              ', syxResult.address)
    debug('  - bpt:              ', bptResult.address)
    debug('  - rewardPool:       ', rewardPoolResult.address)
  }

  let comptrollerAddress = comptroller
  // if not set by named config
  if (!comptrollerAddress) {
    const contract = isTestEnvironment ? 'ComptrollerHarness' : 'Comptroller'
    const comptrollerResult = await deploy('Comptroller', {
      contract,
      from: deployer,
      skipIfAlreadyDeployed: true
    })
    comptrollerAddress = comptrollerResult.address
    const comptrollerContract = await buidler.ethers.getContractAt('Comptroller', comptrollerResult.address, signer)
    if (adminAccount !== deployer) {
      await comptrollerContract.transferOwnership(adminAccount)
    }
  }

  let reserveAddress = reserve

  // if not set by named config
  const reserveResult = await deploy('Reserve', {
    from: deployer,
    skipIfAlreadyDeployed: true
  })
  reserveAddress = reserveResult.address

  const reserveContract = await buidler.ethers.getContractAt('Reserve', reserveResult.address, signer)
  if (adminAccount !== deployer) {
    await reserveContract.transferOwnership(adminAccount)
  }

  const reserveRegistryResult = await deploy('ReserveRegistry', {
    contract: 'Registry',
    from: deployer,
    skipIfAlreadyDeployed: true
  })
  const reserveRegistryContract = await buidler.ethers.getContractAt('Registry', reserveRegistryResult.address, signer)
  if ((await reserveRegistryContract.lookup()) != reserveResult.address) {
    await reserveRegistryContract.register(reserveResult.address)
  }
  if (adminAccount !== deployer) {
    await reserveRegistryContract.transferOwnership(adminAccount)
  }

  debug('\n  Deploying ControlledTokenProxyFactory...')
  const controlledTokenProxyFactoryResult = await deploy('ControlledTokenProxyFactory', {
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying TicketProxyFactory...')
  const ticketProxyFactoryResult = await deploy('TicketProxyFactory', {
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying StakePrizePoolProxyFactory...')
  const stakePrizePoolProxyFactoryResult = await deploy('StakePrizePoolProxyFactory', {
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying SyxPrizePoolProxyFactory...')
  const syxPrizePoolProxyFactoryResult = await deploy('SyxPrizePoolProxyFactory', {
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying SponsorProxyFactory...')
  const sponsorProxyFactoryResult = await deploy('SponsorProxyFactory', {
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying ControlledTokenBuilder...')
  const controlledTokenBuilderResult = await deploy('ControlledTokenBuilder', {
    args: [trustedForwarder, controlledTokenProxyFactoryResult.address, ticketProxyFactoryResult.address],
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying SingleRandomWinnerCoinFactory...')
  let singleRandomWinnerCoinFactoryResult
  if (isTestEnvironment && !harnessDisabled) {
    debug('\n  Deploying SingleRandomWinnerCoinHarnessProxyFactory...')
    singleRandomWinnerCoinFactoryResult = await deploy('SingleRandomWinnerCoinFactory', {
      contract: 'SingleRandomWinnerCoinHarnessProxyFactory',
      from: deployer,
      skipIfAlreadyDeployed: true
    })
  } else {
    singleRandomWinnerCoinFactoryResult = await deploy('SingleRandomWinnerCoinFactory', {
      from: deployer,
      skipIfAlreadyDeployed: true
    })
  }

  debug('\n  Deploying SingleRandomWinnerCoinBuilder...')
  const singleRandomWinnerBuilderResult = await deploy('SingleRandomWinnerCoinBuilder', {
    args: [
      singleRandomWinnerCoinFactoryResult.address,
      trustedForwarder,
      controlledTokenProxyFactoryResult.address,
      ticketProxyFactoryResult.address
    ],
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying StakePrizePoolBuilder...')
  const stakePrizePoolBuilderResult = await deploy('StakePrizePoolBuilder', {
    args: [
      reserveRegistryResult.address,
      trustedForwarder,
      stakePrizePoolProxyFactoryResult.address,
      singleRandomWinnerBuilderResult.address
    ],
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying SyxPrizePoolBuilder...')
  const syxPrizePoolBuilderResult = await deploy('SyxPrizePoolBuilder', {
    args: [
      reserveRegistryResult.address,
      trustedForwarder,
      syxPrizePoolProxyFactoryResult.address,
      singleRandomWinnerBuilderResult.address,
      sponsorProxyFactoryResult.address
    ],
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  

  // Display Contract Addresses
  debug('\n  Contract Deployments Complete!\n')
  debug('  - TicketProxyFactory:             ', ticketProxyFactoryResult.address)
  debug('  - Reserve:                        ', reserveAddress)
  // debug('  - Comptroller:                    ', comptrollerAddress)
  // debug('  - CompoundPrizePoolProxyFactory:  ', compoundPrizePoolProxyFactoryResult.address)
  debug('  - ControlledTokenProxyFactory:    ', controlledTokenProxyFactoryResult.address)
  debug('  - SingleRandomWinnerCoinFactory: ', singleRandomWinnerCoinFactoryResult.address)
  debug('  - ControlledTokenBuilder:         ', controlledTokenBuilderResult.address)
  debug('  - SingleRandomWinnerBuilder:      ', singleRandomWinnerBuilderResult.address)
  // debug('  - CompoundPrizePoolBuilder:       ', compoundPrizePoolBuilderResult.address)
  // debug('  - yVaultPrizePoolBuilder:         ', yVaultPrizePoolBuilderResult.address)
  debug('  - StakePrizePoolBuilder:          ', stakePrizePoolBuilderResult.address)
  debug('  - SyxPrizePoolBuilder:          ', syxPrizePoolBuilderResult.address)
  debug('  - SponsorBuilder:          ', sponsorProxyFactoryResult.address)
  
  // if (permitAndDepositDaiResult) {
  //   debug('  - PermitAndDepositDai:            ', permitAndDepositDaiResult.address)
  // }

  debug('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}
