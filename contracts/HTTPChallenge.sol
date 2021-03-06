pragma solidity 0.5.3;

import "provable-eth-api/provableAPI_0.5.sol";
import "./util.sol";

/**
 * @title Provable-Domain HTTP Challenge Contract
 *
 * @author Ken Sze <acken2@outlook.com>
 *
 * @notice This contracts defines a HTTP challenge that the domain owner can take and prove their ownership.
 *
 * @dev This token contract uses the Provable Ethereum API underneath.
 */
contract HTTPChallenge is usingProvable, util {

    /// Mapping from the uint256 challenge ID to the declared controller of the domain
    mapping(uint256 => address) private owners;
    /// Mapping from the uint256 challenge ID to the encoded challenge string
    mapping(uint256 => string) private challenges;
    /// Mapping from the uint256 challenge ID to the declared domain
    mapping(uint256 => string) private domains;
    /// Mapping from Provable bytes32 queryId to the uint256 challenge ID
    mapping(bytes32 => uint256) private provableIds;
    /// Mapping from the uint256 challenge ID to that challenge status
    mapping(uint256 => bool) private status;

    /// HTML challenge prefix
    string constant HTTPPrefix = "<html><body>";
    /// HTML challenge suffix
    string constant HTTPSuffix = "</body></html>";

    /// Storing the maximum gas that _callback would use
    uint256 private GAS_LIMIT;

    /// Event that will be emitted at the initialization of a HTTP challenge
    event HTTPChallengeInitialized(uint256 indexed challengeId, address indexed owner, string domain);
    /// Event that will be emitted upon each failure to solve a HTTP challenge
    event HTTPChallengeFailed(uint256 indexed challengeId, bytes proof);
    /// Event that will be emitted upon solving a HTTP challenge
    event HTTPChallengeSucceed(uint256 indexed challengeId, bytes proof);

    /**
     * @notice Initialize the contract
     * @param gasLimit uint256 maximum gas that the _callback function would consumes
     */
    constructor(uint256 gasLimit) public {
        // Demand TLSNotary proof from Provable
        provable_setProof(proofType_TLSNotary | proofStorage_IPFS);
        // Set gas limit required for __callback
        GAS_LIMIT = gasLimit;
    }

     /**
     * @notice Initialize a HTTP challenge
     * @param owner address address that declared that they control the domain
     * @param domain string domain controlled by the owner
     * @return uint256 challenge ID initialized
     * @dev Child contract should implement a function that call this internal function to initiate the
     * validation challenge.
     */
    function initChallenge(address owner, string memory domain) internal returns (uint256) {
        // Create an unique challengeId for each challenge
        uint256 challengeId = uint256(keccak256(abi.encodePacked(owner, domain, block.number)));
        // Map the challengeId to its owner
        owners[challengeId] = owner;
        // Map the challengeId to the associated domain
        domains[challengeId] = domain;
        // Map the challengeId to the challenge string, which is the address of the owner
        challenges[challengeId] = toAsciiString(owner);
        // Emit HTTPChallengeInitialized event
        emit HTTPChallengeInitialized(challengeId, owner, domain);
        // Return challenge ID
        return challengeId;
    }

    /**
     * @notice Get the challenge URL of an initialized HTTP challenge
     * @param challengeId uint256 challenge ID
     * @return string the challenge URL that the challenge HTML should be uploaded to
     */
    function _getChallengeURL(uint256 challengeId) private view returns (string memory) {
        // Challenge URL: declared_domain/_challengeId.html
        return string(abi.encodePacked(domains[challengeId], "/_", challenges[challengeId], ".html"));
    }

    /**
     * @notice Get the detail of an initialized HTTP challenge
     * @param challengeId uint256 challenge ID
     * @return (string, string) the first parameters is the challenge URL that the HTML should be uploaded to,
     * and the second parameter is the challenge HTML string to be uploaded to the challenge URL
     */
    function getChallenge(uint256 challengeId) public view returns (string memory, string memory) {
        // URL: declared_domain/_challengeId.html
        string memory requiredURL = _getChallengeURL(challengeId);
        // HTML content must return the address of the declared controller of the domain
        string memory challengeHTML = string(abi.encodePacked(HTTPPrefix, challenges[challengeId], HTTPSuffix));
        return (requiredURL, challengeHTML);
    }

     /**
     * @notice Get the Ethereum cost for each attempt in solving the HTTP challenge that MUST be sent
     * together when calling the solveChallenge method
     * @param gasPrice uint256 the gas price intended to be used during the Provable callback
     * @return uint the Ethereum cost in Wei
     */
    function getProvableCost(uint256 gasPrice) public returns (uint256) {
        // Set gas price to the intended value
        provable_setCustomGasPrice(gasPrice);
        // Return the estimated gas price
        return provable_getPrice("URL", GAS_LIMIT);
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
     * @dev Child contract should implement a function that call this internal function to initiate the
     * validation process.
     */
    function solveChallenge(uint256 challengeId) internal {
        // Check if the Ether sent can and exactly cover the cost required by Provable
        require(msg.value == getProvableCost(tx.gasprice), "HTTPChallenge: incorrect funds sent");
        // Check if the challenge has already been completed
        require(!status[challengeId], "HTTPChallenge: specified challenge is already completed");
        // Provable query
        string memory queryURL = string(abi.encodePacked("html(", _getChallengeURL(challengeId), ").xpath(//body/text())"));
        bytes32 queryId = provable_query("URL", queryURL, GAS_LIMIT);
        // Record the queryId
        provableIds[queryId] = challengeId;
    }

    /**
     * @notice Callback function used by Provable
     * @param queryId bytes32 Provable query ID
     * @param result string result of the query
     * @param proof bytes authenticity proofs in the form of IPFS hash
     * @dev implementing _callbackChild method would allow any child contract to take further actions once the verification is successful
     */
    function __callback(bytes32 queryId, string memory result, bytes memory proof) public {
        // Check if the msg.sender is Provable
        require(msg.sender == provable_cbAddress(), "HTTPChallenge: _callback can only be called by Provable");
        // Obtain the challenge ID from the query ID
        uint256 challengeId = provableIds[queryId];
        // Check if the result is as expected which is the address of the declared controller
        if (keccak256(abi.encodePacked(result)) != keccak256(abi.encodePacked(challenges[challengeId]))) {
            // Emit HTTPChallengeFailed
            emit HTTPChallengeFailed(challengeId, proof);
            // Failed validation, call _callbackChild
            _callbackChild(challengeId, false);
        }
        else {
            // Successful validation, completing the challenge
            status[challengeId] = true;
            emit HTTPChallengeSucceed(challengeId, proof);
            _callbackChild(challengeId, true);
        }
    }

    /**
     * @notice Secondary callback function that can be implemented by child contract
     * @param challengeId uint256 challenge ID
     * @param validated bool validation status of the challenge
     */
    function _callbackChild(uint256 challengeId, bool validated) internal;

}