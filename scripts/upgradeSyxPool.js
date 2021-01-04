const { ethers, upgrades } = require("@nomiclabs/buidler")

const syxPrizePoolAddress = "0xD55AD67b44cfDd6C6443A6f0305187194F491325"

const main = async () => {
  const SyxPrizePoolFactory = await ethers.getContractFactory("SyxPrizePool_V2")
  const syxPrizePool = await upgrades.upgradeProxy(syxPrizePoolAddress, SyxPrizePoolFactory, {
    unsafeAllowCustomTypes: true
  })
  await syxPrizePool.deployed()
  console.log("PrizePool:", syxPrizePool.address)
}

main()
