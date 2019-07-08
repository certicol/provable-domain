# Provable Domain

[![Build Status](https://travis-ci.org/certicol/provable-domain.svg?branch=master)](https://travis-ci.org/certicol/provable-domain)
[![Coverage Status](https://coveralls.io/repos/github/certicol/provable-domain/badge.svg?branch=master)](https://coveralls.io/github/certicol/provable-domain?branch=master)

This repository store contract that aims at verifying one's ownership to a domain using Provable Ethereum API.

The idea is similar to Let's Encrypt where one has to show that he/she has control over the domain by returning a specific content in a specific URL under the domain. In its current implementation (HTTPChallenge.sol), one must be able to return the address in the body section of an HTML file under http(s)://declared_domain/_address to prove their control and ownership over the domain.

This contract is designed to be used in Certicol but is open for anyone who is interested in this idea.

## Running Automated Test

```
npm install
npm test
```

## Generating Coverage Report

```
npm run coverage
```

## License

Provable Domain is released under the [Apache License 2.0](LICENSE).

## Usage

### Installation

```
npm i provable-domain
```

### Contract Construction

Firstly, you should import HTTPChallenge.sol and extends from it.

In the constructor of HTTPChallenge, you are required to pass a uint256 as the parameter. This defines the gas limit used by the __callback function and must be set in accordance with the total cumulative gas cost of the __callback function. Since any implementer contract can implement their own callback function (see below), this value must be defined by the child contract.

```
import 'provable-domain/contracts/HTTPChallenge.sol';

contract Implementer is HTTPChallenge {

    constructor() HTTPChallenge(x) public {
    }

}
```

This will expose the core methods of HTTPChallenge.sol to your implementer contract described below.

### Initialize an HTTP Challenge

To initialize an HTTP challenge, begins by calling initChallenge() where the owner is the claimed owner of the domain, and the domain is the domain concerned.

This would return a uint256 challengeId that is associated with the initialized challenge.

Since this function is marked as internal, any child contract should include a public/external function that indirectly exposes this function. This also provides the child contract a greater control over the process.

```
function initChallenge(address owner, string memory domain) internal returns (uint256);
```

### Query the Challenge URL and HTML String

As mentioned above, the claimed owner would be required to show a specific string at a specific URL under the concerned domain. The detail of the string and URL can be queried by using the getChallenge().

This function would return an array where the first element is the URL and the second element is the HTML string that must be returned when the URL is accessed.

```
function getChallenge(uint256 challengeId) public view returns (string memory, string memory);
```

### Resolving the HTTP Challenge

Once the URL is prepared as required, the HTTP challenge can be resolved by calling solveChallenge() with the challengeId associated with the challenge to be resolved.

Since this function is marked as internal, any child contract should include a public/external function that indirectly exposes this function. This also provides the child contract a greater control over the process.

```
function solveChallenge(uint256 challengeId) internal;
```

It should be noted since Provable API required payment in Ethereum as a fee. An Ethereum payment identical to the cost returned by getProvableCost() must be included when calling solveChallenge() or else it would reverts.

The fee is dependent upon BOTH the gas limit set in the constructor and the gas price used in the transaction that called solveChallenge() which has to be passed as a parameter in the function.

It is acceptable to call this function as .call() in web3 and it would return the correct value.

```
function getProvableCost(uint256 gasPrice) public returns (uint256)
```

### Default Provable Callback Function

Since Provable can't immediately callback with the query result, the status of the challenge remains as unresolved after the solveChallenge() function is executed.

Once the Provable callback is executed, the contract's __callback function would execute and emits the updated status of the challenge as either an HTTPChallengeFailed or HTTPChallengeSucceed event.

```
/// Event that will be emitted upon each failure to solve a HTTP challenge
event HTTPChallengeFailed(uint256 indexed challengeId, bytes proof);
/// Event that will be emitted upon solving a HTTP challenge
event HTTPChallengeSucceed(uint256 indexed challengeId, bytes proof);
```

### Custom Callback Function

Implementer contract can also implement their own follow-up action by implementing the _callbackChild function. 

This function will be called after the default __callback has finished its execution. Two parameters will be passed which includes the challengeId and the updated status (true if successful or false if failed).

Thus, the gas limit of the __callback function is dependent upon the implementation of the child contract, and the developer must set it in accordance with their own implementation.

```
function _callbackChild(uint256 challengeId, bool validated) internal;
```