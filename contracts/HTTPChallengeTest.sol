pragma solidity 0.5.3;

import "./HTTPChallenge.sol";

/**
 * @title Testing Provable-Domain HTTP Challenge Contract
 *
 * @author Ken Sze <acken2@outlook.com>
 *
 * @notice This contracts defines a sample implementation of the HTTPChallenge contract for testing purposes.
 */
contract HTTPChallengeTest is HTTPChallenge {

    /**
     * @notice Initialize the test contract
     */
    constructor() HTTPChallenge(200000) public {
        // Initialize OAR
        OAR = OracleAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
    }

    /**
     * @notice Initialize a HTTP challenge
     * @param owner address address that declared that they control the domain
     * @param domain string domain controlled by the owner
     * @return uint256 the challenge ID
     */
    function initChallengeTest(address owner, string calldata domain) external returns (uint256) {
        initChallenge(owner, domain);
    }

    /**
     * @notice Secondary callback function that can be implemented by child contract
     * @param challengeId uint256 challenge ID
     * @param validated bool validation status of the challenge
     */
    function _callbackChild(uint256 challengeId, bool validated) internal {
    }

}