const buidler = require("@nomiclabs/buidler")

const setup = async () => {
  const { ethers, getChainId, deployments, upgrades } = buidler
  const toWei = ethers.utils.parseEther

  let {
    deployer,
    rng,
    adminAccount,
    reserve,
    syx,
    svlx,
    miningPool,
    rewardPool,
    rewardPoolId
  } = await getNamedAccounts()

  const chainId = parseInt(await getChainId(), 10)
  const isTestEnvironment = chainId === 31337 || chainId === 1337

  const [signer] = await ethers.getSigners()
  console.log(`Using wallet address: ${signer._address}`)

  let prizePeriodStart = 1609761600
  let prizePeriodSeconds = 60

  if (isTestEnvironment) {
    registry = await deployments.get("Reserve")
    reserve = registry.address

    rngService = await deployments.get("RNGServiceMock")
    rng = rngService.address

    const mockSvlx = await deployments.get("SVLX")
    svlx = mockSvlx.address

    const mockSyx = await deployments.get("mockToken")
    syx = mockSyx.address

    const mockBpt = await deployments.get("mockBpt")
    miningPool = mockBpt.address
    const mockRewardPool = await deployments.get("mockRewardPool")
    rewardPool = mockRewardPool.address

    rewardPoolId = 0

    prizePeriodStart = 10
    prizePeriodSeconds = 10
  }

  const syxSingleWinnerConfig = {
    proxyAdmin: ethers.constants.AddressZero,
    rngService: rng,
    prizePeriodStart: prizePeriodStart,
    prizePeriodSeconds: prizePeriodSeconds,
    ticketName: "pooled Velas",
    ticketSymbol: "pVLX",
    sponsorshipName: "Sponsorship",
    sponsorshipSymbol: "SPON",
    ticketCreditLimitMantissa: toWei("0.1"),
    ticketCreditRateMantissa: toWei("0.001"),
    externalERC20Awards: [syx]
  }

  console.log({ syxSingleWinnerConfig })

  const syxPrizePoolConfig = {
    token: svlx,
    maxExitFeeMantissa: toWei("0.5"),
    maxTimelockDuration: 1000
  }

  console.log({ syxPrizePoolConfig })

  let decimals = 18

  const { deploy } = deployments

  // Deploy the prize pool

  let initArgs = []

  initArgs = [
    reserve,
    [],
    syxPrizePoolConfig.maxExitFeeMantissa.toString(),
    syxPrizePoolConfig.maxTimelockDuration
    // syxPrizePoolConfig.token
  ]

  console.log({ initArgs })

  const SyxPrizePoolFactory = await ethers.getContractFactory("SyxPrizePool")
  const syxPrizePool = await upgrades.deployProxy(SyxPrizePoolFactory, initArgs, { unsafeAllowCustomTypes: true })
  await syxPrizePool.deployed()
  console.log("PrizePool:", syxPrizePool.address)

  // const syxPrizePool = await deploy("SyxPrizePool", {
  //   from: deployer,
  //   proxy: "initialize",
  //   args: initArgs
  // })

  // Deploy ticket token

  initArgs = [syxSingleWinnerConfig.ticketName, syxSingleWinnerConfig.ticketSymbol, decimals, syxPrizePool.address]
  console.log({ initArgs })

  const TicketFactory = await ethers.getContractFactory("Ticket")
  const pVlx = await upgrades.deployProxy(TicketFactory, initArgs, { unsafeAllowCustomTypes: true })
  await pVlx.deployed()
  console.log("pVlx:", pVlx.address)

  // const pVlx = await deploy("Ticket", {
  //   from: deployer,
  //   proxy: "initialize",
  //   args: initArgs
  // })

  // Deploy sponsorship token

  initArgs = [
    syxSingleWinnerConfig.sponsorshipName,
    syxSingleWinnerConfig.sponsorshipSymbol,
    decimals,
    syxPrizePool.address
  ]
  console.log({ initArgs })

  const ControlledTokenFactory = await ethers.getContractFactory("ControlledToken")
  const sponsorship = await upgrades.deployProxy(ControlledTokenFactory, initArgs, { unsafeAllowCustomTypes: false })
  await sponsorship.deployed()
  console.log("sponsorship:", sponsorship.address)

  // const sponsorship = await deploy("ControlledToken", {
  //   from: deployer,
  //   proxy: "initialize",
  //   args: [
  //     syxSingleWinnerConfig.sponsorshipName,
  //     syxSingleWinnerConfig.sponsorshipSymbol,
  //     decimals,
  //     syxPrizePool.address
  //   ]
  // })

  // Deploy the strategy

  initArgs = [
    syxSingleWinnerConfig.prizePeriodStart,
    syxSingleWinnerConfig.prizePeriodSeconds,
    syxPrizePool.address,
    pVlx.address,
    sponsorship.address,
    syxSingleWinnerConfig.rngService,
    syxSingleWinnerConfig.externalERC20Awards
  ]
  console.log({ initArgs })

  const SyxSingleWinnerFactory = await ethers.getContractFactory("SyxSingleWinner")
  const syxSingleWinner = await upgrades.deployProxy(SyxSingleWinnerFactory, initArgs, {
    unsafeAllowCustomTypes: true
  })
  await syxSingleWinner.deployed()
  console.log("syxSingleWinner:", syxSingleWinner.address)

  // const syxSingleWinner = await deploy("SyxSingleWinner", {
  //   from: deployer,
  //   proxy: "initialize",
  //   args: [
  //     syxSingleWinnerConfig.prizePeriodStart,
  //     syxSingleWinnerConfig.prizePeriodSeconds,
  //     syxPrizePool.address,
  //     pVlx.address,
  //     sponsorship.address,
  //     rng,
  //     syxSingleWinnerConfig.externalERC20Awards
  //   ]
  // })

  const pVlxAddress = await syxSingleWinner.ticket()
  console.log({ pVlxAddress })
  const sponsorshipAddress = await syxSingleWinner.sponsorship()
  console.log({ sponsorshipAddress })

  await syxPrizePool.addControlledToken(pVlxAddress)
  await syxPrizePool.addControlledToken(sponsorshipAddress)

  await syxPrizePool.setPrizeStrategy(syxSingleWinner.address)

  await syxPrizePool.setCreditPlanOf(
    pVlxAddress,
    syxSingleWinnerConfig.ticketCreditRateMantissa,
    syxSingleWinnerConfig.ticketCreditLimitMantissa
  )

  // Deploy Sponsor

  initArgs = [syxPrizePool.address, pVlxAddress, miningPool, rewardPool, rewardPoolId]
  console.log({ initArgs })

  const SponsorFactory = await ethers.getContractFactory("Sponsor")
  const sponsor = await upgrades.deployProxy(SponsorFactory, initArgs, { unsafeAllowCustomTypes: false })
  await sponsor.deployed()
  console.log("sponsor:", sponsor.address)

  // const sponsor = await deploy("Sponsor", {
  //   from: deployer,
  //   proxy: "initialize",
  //   args: [
  //     syxPrizePool.address,
  //     pVlx.address,
  //     miningPool,
  //     rewardPool,
  //     rewardPoolId
  //   ]
  // })

  await syxSingleWinner.setSponsor(sponsor.address)
  await syxPrizePool.setSponsor(sponsor.address)
}

setup()
