const buidler = require("@nomiclabs/buidler")

const main = async () => {
  const { ethers, getChainId, deployments, upgrades } = buidler
  const toWei = ethers.utils.parseEther

  const [signer] = await ethers.getSigners()
  console.log(`Using wallet address: ${signer._address}`)

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

  let prizePeriodStart = 1609761600
  let prizePeriodSeconds = 60

  const syxPrizePoolAddress = "0xD55AD67b44cfDd6C6443A6f0305187194F491325"
  const pVlxAddress = "0x85275F00e595924CB0D2229218F4dAEC9C040271"
  const sponsorshipAddress = "0xe16950078d5af73AaE9e6655BA3734E9cB72509d"
  const syxSingleWinnerAddress = "0x81565A10CcC6AEc3B66B5f1C1529261BdA1f1189"
  const sponsorAddress = "0x11425b1Ba41Df91FABeDaaCDCE28f7d04638DDD4"

  const syxPrizePool = await ethers.getContractAt("SyxPrizePool", syxPrizePoolAddress, signer)
  // const pVlx = await ethers.getContractAt("Ticket", pVlxAddress, signer)
  // console.log({ pVlx: pVlx.address })
  // const sponsorship = await ethers.getContractAt("ControlledToken", sponsorshipAddress, signer)
  // console.log({ sponsorship: sponsorship.address })

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

  initArgs = [
    syxSingleWinnerConfig.prizePeriodStart,
    syxSingleWinnerConfig.prizePeriodSeconds,
    syxPrizePool.address,
    pVlxAddress,
    sponsorshipAddress,
    syxSingleWinnerConfig.rngService,
    syxSingleWinnerConfig.externalERC20Awards
  ]
  console.log({ initArgs })

  const SyxSingleWinnerFactory = await ethers.getContractFactory("SyxSingleWinner")
  const syxSingleWinner = await upgrades.deployProxy(SyxSingleWinnerFactory, initArgs, {
    unsafeAllowCustomTypes: true
  })
  await syxSingleWinner.deployed()

  const syxSingleWinner = await ethers.getContractAt("SyxSingleWinner", syxSingleWinnerAddress, signer)
  console.log("syxSingleWinner:", syxSingleWinner.address)

  await syxPrizePool.addControlledToken(pVlxAddress)
  await syxPrizePool.addControlledToken(sponsorshipAddress)

  await syxPrizePool.setPrizeStrategy(syxSingleWinner.address)

  await syxPrizePool.setCreditPlanOf(
    pVlxAddress,
    syxSingleWinnerConfig.ticketCreditRateMantissa,
    syxSingleWinnerConfig.ticketCreditLimitMantissa
  )

  // Deploy Sponsor

  initArgs = [syxPrizePool.address, pVlxAddress, miningPool, rewardPool, "0"]
  console.log({ initArgs })

  const SponsorFactory = await ethers.getContractFactory("Sponsor")
  const sponsor = await upgrades.deployProxy(SponsorFactory, initArgs, { unsafeAllowCustomTypes: false })
  await sponsor.deployed()
  console.log("sponsor:", sponsor.address)

  await syxSingleWinner.setSponsor(sponsor.address, { gasPrice: ethers.utils.parseUnits("1.0", "gwei") })
  await syxPrizePool.setSponsor(sponsor.address, { gasPrice: ethers.utils.parseUnits("1.0", "gwei") })
}

main()
