const { ethers, upgrades } = require("@nomiclabs/buidler")

const syxPrizePoolAddress = "0x8fB2446c80762ca8C2516b1AC40727839C44AC53"

const main = async () => {
  const SyxPrizePoolFactory = await ethers.getContractFactory("SyxPrizePool_V2")
  const syxPrizePool = await upgrades.upgradeProxy(syxPrizePoolAddress, SyxPrizePoolFactory, {
    unsafeAllowCustomTypes: true
  })
  await syxPrizePool.deployed()
  console.log("PrizePool:", syxPrizePool.address)
}

main()
