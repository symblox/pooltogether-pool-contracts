const buidler = require('@nomiclabs/buidler')
const { deployments } = require('@nomiclabs/buidler')

let addresses = {
  106: {},
  111: {
    syx: '0x28a6312D786e9d7a78637dD137AbeF5332F3b2Aa',
    svlx: '0xCd0739c910aA4d118F751beE38712409479D4782',
    bpt: '0x3FBaf23119a999336bb9bB0744bcC6f60540B4B4', //vlxSyx reward pool bpt token
    rewardPool: '0x2c140E4561ef42c20B60E600CA52B86147858AC5',
    rewardPoolId: 0, //vlxSyx reward pool id
    rngService: '0xB4fb2B1FBB995bBb9A2c8481c61c5Be1c63e081b'
  },
  1337: {
    rewardPoolId: 0
  },
  31337: {
    rewardPoolId: 0
  }
}

async function getEvents(tx) {
  let receipt = await buidler.ethers.provider.getTransactionReceipt(tx.hash)
  return receipt.logs.reduce((parsedEvents, log) => {
    try {
      parsedEvents.push(builder.interface.parseLog(log))
    } catch (e) {}
    return parsedEvents
  }, [])
}

const setup = async () => {
  const { ethers, getChainId } = buidler
  const { AddressZero } = ethers.constants
  const toWei = ethers.utils.parseEther

  const chainId = parseInt(await getChainId(), 10)
  const isTestEnvironment = chainId === 31337 || chainId === 1337

  ;[wallet] = await ethers.getSigners()
  console.log(`Using wallet address: ${wallet._address}`)

  //   await deployments.fixture()
  builder = await ethers.getContractAt(
    'SyxPrizePoolBuilder',
    (await deployments.get('SyxPrizePoolBuilder')).address,
    wallet
  )
  console.log(`builder address: ${builder.address}`)

  if (isTestEnvironment) {
    rngService = await deployments.get('RNGServiceMock')
    addresses[chainId].rngService = rngService.address

    svlx = await deployments.get('SVLX')
    addresses[chainId].svlx = svlx.address

    syx = await deployments.get('mockToken')
    addresses[chainId].syx = syx.address
    console.log({ syxAddress: syx.address })

    const bpt = await deployments.get('mockBpt')
    addresses[chainId].bpt = bpt.address
    const rewardPool = await deployments.get('mockRewardPool')
    addresses[chainId].rewardPool = rewardPool.address
  }

  singleRandomWinnerConfig = {
    proxyAdmin: AddressZero,
    rngService: addresses[chainId].rngService,
    prizePeriodStart: 20,
    prizePeriodSeconds: 10,
    ticketName: 'pooled Velas',
    ticketSymbol: 'pVLX',
    sponsorshipName: 'Sponsorship',
    sponsorshipSymbol: 'SPON',
    ticketCreditLimitMantissa: toWei('0.1'),
    ticketCreditRateMantissa: toWei('0.001'),
    externalERC20Awards: [addresses[chainId].syx]
  }

  syxPrizePoolConfig = {
    token: addresses[chainId].svlx,
    maxExitFeeMantissa: toWei('0.5'),
    maxTimelockDuration: 1000
  }
  let decimals = 18

  let tx = await builder.createSingleRandomWinner(syxPrizePoolConfig, singleRandomWinnerConfig, decimals)
  let events = await getEvents(tx)
  let prizePoolCreatedEvent = events.find(e => e.name == 'PrizePoolCreated')
  const prizePool = await ethers.getContractAt('SyxPrizePool', prizePoolCreatedEvent.args.prizePool, wallet)
  console.log(`PrizePool address: ${prizePool.address}`)

  const prizeStrategy = await ethers.getContractAt('SingleRandomWinnerCoin', await prizePool.prizeStrategy(), wallet)
  const ticketAddress = await prizeStrategy.ticket()
  console.log({ ticketAddress })
  const sponsorshipAddress = await prizeStrategy.sponsorship()
  console.log({ sponsorshipAddress })

  //if(isTestEnvironment){
  let createTx = await builder.createSponsor()
  let createEvents = await getEvents(createTx)
  let sponsorCreatedEvent = createEvents.find(e => e.name == 'SponsorCreated')
  const sponsor = await ethers.getContractAt('Sponsor', sponsorCreatedEvent.args.sponsor, wallet)
  console.log(`Sponsor address: ${sponsor.address}`)

  //Initialize first, set owner and then setSponsor
  await sponsor.initialize(
    prizePool.address,
    ticketAddress,
    addresses[chainId].bpt,
    addresses[chainId].rewardPool,
    addresses[chainId].rewardPoolId
  )
  await prizeStrategy.setSponsor(sponsor.address)
  await prizePool.setSponsor(sponsor.address)
  // }else{
  //   //Manually call after the transaction pool is deployed
  // }
}

setup()
