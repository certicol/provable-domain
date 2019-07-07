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
     * @notice Solve the HTTP challenge
     * @param challengeId uint256 challenge ID
     * @dev This function can throws if the transaction is executed with insufficient Ethereum
     * or too much Ethereum as compared to the cost returned by getProvableCost. The cost is dependent
     * on the gas price used in the transaction that calls this function, since the callback from
     * Provable would use an identical gas price as the gas price used in the transaction that
     * calls this function. This, therefore, give the user an option to choose the gas price that would
     * like to use.
     */
    function solveChallengeTest(uint256 challengeId) public payable {
        solveChallenge(challengeId);
    }

    /**
     * @notice Secondary callback function that can be implemented by child contract
     * @param challengeId uint256 challenge ID
     * @param validated bool validation status of the challenge
     */
    function _callbackChild(uint256 challengeId, bool validated) internal {
    }

}