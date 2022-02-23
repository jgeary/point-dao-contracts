# Point DAO

Point DAO aims to facilitate [PartyBid](https://github.com/PartyDAO/partybid)-style collective ownership of Urbit galaxies.

This repo contains v1 of the protocol.

## Contracts

```
// Main treasury and governance controller
PointTreasury

// Generic governance, controlled by PointTreasury
PointGovernor

// ERC20 voting token
Point

// Party-buy galaxies
GalaxyAsks

// Safely custody galaxies with minimum necessary functions exposed for governance
GalaxyLocker

// Deploy all contracts above atomically
Deployer
```

## GalaxyAsks Mechanics

There are two main ways that GalaxyAsks enables Point DAO to acquire a galaxy:
 - A galaxy owner can call `swapGalaxy` to immediately transfer their galaxy to the DAO and receive 1000 POINT.
 - A galaxy owner can call `createAsk` to list their galaxy for sale. The owner asks for a certain ETH:POINT rate as well as some amount of POINT. If it is approved by governance, then anybody can contribute to filling the ask, and ultimately the DAO acquires the galaxy and distributes a total of 1000 POINT to the owner and contributors.
 
Note that a galaxy owner that transfers their galaxy to Point DAO via GalaxyAsks *can not* automatically get their galaxy back. Once Point DAO owns it, it's up to the DAO what they do with the galaxy. The motivation for the project was for the DAO to vote on Urbit proposals with their galaxies in perpetuity. Also, there can only be one live Ask at a time.

For example: Alice owns `~zod` and values it at 1000 ETH. She wants to sell it, but she also wants to retain some Urbit voting power. She can call `createAsk(0, 1*10**18, 100*10**18)` meaning she would like to sell `~zod` at 1 ETH per POINT, and she wants 100 POINT for herself. If governance approves this ask, then anybody can contribute some of the 900 remaining unallocated ETH. When the asking price is hit, Alice receives 900 ETH and 100 POINT, the DAO receives the galaxy, and the contributors can claim their fair share of the remaining 900 POINT.

See the GalaxyAsks [integration test](https://github.com/jgeary/point-dao-contracts/blob/master/contracts/test/GalaxyAsks.integration.t.sol) to see a thorough example of how it works in code.

## Galaxy Locker

Rather than giving galaxies direcly to the token governed treasury, galaxies are transferred to the GalaxyLocker. GalaxyLocker exposes just enough functions for governance to set management, voting and spawn proxies. If governance wants to recover a galaxy from the locker, they must burn 1000 POINT. (More on token mechanics below).

## Governance and Urbit Proposals
The governance system uses standard general-purpose openzeppelin governance contracts, so it is battle-tested and compatible with tools like [Tally](https://www.withtally.com/). In the interest of minimizing transaction fees, the DAO should do snapshot votes for each Urbit proposal to get a yes/no answer, and then a proposer can propose an onchain transaction which would submit that winning answer to Urbit's Polls contract on behalf of each galaxy owned by the treasury.

## Token
POINT is an ERC20 token with a max supply of 284,444.44... POINT. This comes from:

- If GalaxyAsks processed all 256 Urbit galaxies it would distribute 256 * 1000 POINT tokens. Note that GalaxyLocker burns 1000 POINT if a galaxy leaves the locker, so the net supply does not increase when one galaxy is processed through GalaxyAsks multiple times.
- The other 10% is intended for team, airdrops, grants and other incentives.

POINT is mintable and burnable. GalaxyAsks is the only authorized minter and GalaxyLocker is the only authorized burner, forever. It is also pausable. Token transfers are paused at first, but governance can vote to unpause transfers. GalaxyAsks can still mint and GalaxyLocker can still burn when transfers are paused. 


## To Do
- [ ] Long term vesting and inflation contract for treasury POINT tokens
- [ ] Research and implement option for galaxy owners to become the management proxy once governance acquires their galaxy, ideally without breaking continuity
- [x] GalaxyLocker contract with minimum necessary functions (for governance only) to store galaxies and require burning 1000 POINT to transfer galaxy elsewhere
- [ ] Thoroughly test the governance module voting on Urbit proposals
- [ ] Research ideal parameters (timelock, voting period, quorum etc) to maximize compatibility with Urbit governance and minimize attack surface area.
- [ ] Write hardhat deploy script that can run Deployer and verify all contracts on etherscan
- [ ] Deploy on testnet, manually test
