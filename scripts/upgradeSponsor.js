const { ethers, upgrades } = require("@nomiclabs/buidler")

const sponsorAddress = "0x11425b1Ba41Df91FABeDaaCDCE28f7d04638DDD4"

const main = async () => {
  const SponsorFactory = await ethers.getContractFactory("Sponsor")
  const newSponsor = await upgrades.upgradeProxy(sponsorAddress, SponsorFactory, {
    unsafeAllowCustomTypes: true
  })
  await newSponsor.deployed()
  console.log("Sponsor:", newSponsor.address)
}

main()
