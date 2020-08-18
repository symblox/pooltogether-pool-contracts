const { PoolEnv } = require('./support/PoolEnv')
const ethers = require('ethers')

const toWei = (val) => ethers.utils.parseEther('' + val)

describe('Referral volume drip', () => {

  let env

  beforeEach(() => {
    env = new PoolEnv()
  })

  it('should drip users governance tokens', async () => {
    await env.createPool({ prizePeriodSeconds: 10, exitFee: '0.1', creditRate: '0.01' })
    await env.setCurrentTime(20)
    await env.volumeDripGovernanceToken({ dripAmount: '100', periodSeconds: 10, startTime: 20, isReferral: true })
    await env.setCurrentTime(30)
    await env.buyTickets({ user: 1, tickets: '10', referrer: 2 })
    await env.setCurrentTime(40)
    await env.claimVolumeDrip({ user: 2, index: 1 })
    await env.expectUserToHaveGovernanceTokens({ user: 2, tokens: '100' })
  })
})