This repository contains a general voting contract designed to be the community polling counterpart to [ds-chief](https://github.com/dapphub/ds-chief)

## **Background**

In the past, ds-chief was used to gauge MKR holder sentiment. But, this had profound limitations such as the inability to run multiple concurrent polls and unwanted cross-contamination between polls and executive votes. So, a new design phase for a decoupled polling contract began with the goals of: censorship resistance, cryptographic verifiability, on-chain audit-ability, and minimal on-chain computation/ gas efficiency. 

## **Summary**

The symbolic voting contract is an extremely lightweight contract that can really be thought of as a specialized event emitter. All votes and polls are simply events emitted by this contract and all tallying is done off-chain (a fact which means the contract itself requires almost no storage and very little gas). The tradeoff is that, without state, other smart contracts can't query it for information. However, because symbolic votes don't need to be binding on-chain, it was decided that whatever could be pushed to social layer, should be. In brief, the idea here is that voters signal their intent with on-chain events, then services and community members can, using the rules defined in each poll, tally the polls and imbue them with meaning off-chain (eg by summing up the amount of MKR voting for each poll option at a certain block).

## **The Polls**

The polls are, like everything in the symbolic voting contract, emitted events. Specifically, the poll event contains the poll's start date, its end date, and the hash of the contents of the poll details, rules, and metadata. By emitting the hash of a poll document, voters can trust that the content and rules of a poll does not change throughout its lifetime. It also means that maker community members can cryptographically verify for themselves that the hash of the content shown on frontends matches what they're voting for on-chain. It's worth mentioning that *all* the information for the poll is contained within the hashed document, including the voting options, the context for the poll, and the rules that would allow one to tally the poll.

## **Vote Tallying**

Again — unlike ds-chief, the votes are not tallied on-chain. Instead, for the foundation's frontend, the votes are tracked off-chain, cached, and presented via vote.makerdao. While this is done in a centralized way, because the all voting events and MKR token balance are available on-chain, any voter is able to make his/ her own cache and serve the same data, or, in the very least, they could verify that what the foundation's dashboard displays is correct. The current tallying method for polls created by the foundation is to take an address's voting weight at the either the latest block or the block specified by the poll's end date (if the poll has ended) where voting weight is determined to be:

- `MKR amount locked in chief directly + MKR account balance` for all voters
- if the voter has a proxy associated with their address, then it's that plus `MKR amount locked in chief via vote proxy + (for their linked wallet) MKR locked in chief directly + (for linked wallet) MKR account balance`
