const buidler = require('@nomiclabs/buidler')
const { deployments } = require('@nomiclabs/buidler')

let addresses = {
  106: {},
  111: {
    syx: "0xC20932B245840CA1C6F8c9c90BDb2F4E0289DE48",
    wvlx: "0x78f18612775a2c54efc74c2911542aa034fe8d3f",
    //bpt: "0xF819b60A55c2C889584CF051C412ed4ae8449C1E", //pVLX reward pool bpt token
    //rewardPool: "0x8b2B0CE402b33b5A2744371311E3053EAB2E2f3d",
    //rewardPoolId: 2, //pVLX reward pool id
    rngService: "0xB4fb2B1FBB995bBb9A2c8481c61c5Be1c63e081b"
  },
  1337: {},
  31337: {}
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

   if(isTestEnvironment){
    rngService = await deployments.get('RNGServiceMock')
    addresses[chainId].rngService = rngService.address;

    wvlx = await deployments.get('WVLX')
    addresses[chainId].wvlx = wvlx.address;

    syx = await deployments.get('mockToken')
    const Syx = await ethers.getContractAt(
      'mockToken',
      syx.address,
      wallet
    )
    addresses[chainId].syx = syx.address;
    console.log({ syxAddress: syx.address })
    await Syx.initialize("SYX","SYX",18,"100000000000000000000000")

    const bpt = await deployments.get('mockBpt')
    addresses[chainId].bpt = bpt.address;
    const rewardPool = await deployments.get('mockRewardPool')
    addresses[chainId].rewardPool = rewardPool.address;
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
    token: addresses[chainId].wvlx,
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

  const sponsorProxyFactoryResult = await deployments.get('SponsorProxyFactory')
  const sponsorProxyFactory = await ethers.getContractAt(
    'SponsorProxyFactory',
    sponsorProxyFactoryResult.address,
    wallet
  )
  let createTx = await sponsorProxyFactory.create()
  let createEvents = await getEvents(createTx)
  let sponsorCreatedEvent = createEvents.find(e => e.name == 'SponsorCreated')
  const sponsor = await ethers.getContractAt('Sponsor', sponsorCreatedEvent.args.sponsor, wallet)
  console.log(`Sponsor address: ${sponsor.address}`)

  if(isTestEnvironment){
    await prizeStrategy.setSponsor(sponsor.address)
    await prizePool.setSponsor(sponsor.address)
    await sponsor.initialize(prizePool.address,ticketAddress,addresses[chainId].bpt,addresses[chainId].rewardPool,addresses[chainId].rewardPoolId)
  }else{
    //Manually call after the transaction pool is deployed
  }
}

setup()
