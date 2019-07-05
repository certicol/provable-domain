pragma solidity 0.5.3;

import "../node_modules/provable-eth-api/provableAPI_0.5.sol";

/**
 * @title Provable-Domain HTTP Challenge Contract
 *
 * @author Ken Sze <acken2@outlook.com>
 *
 * @notice This contracts defines a HTTP challenge that the domain owner can take and prove their ownership.
 *
 * @dev This token contract uses the Provable Ethereum API underneath.
 */
contract HTTPChallenge is usingProvable {

    /// Mapping from the uint256 challenge ID to the declared controller of the domain
    mapping(uint256 => address) private owners;
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
     */
    function initChallenge(address owner, string memory domain) internal {
        // Create an unique challengeID for each challenge
        uint256 challengeID = uint256(keccak256(abi.encodePacked(owner, domain, block.number)));
        // Map the challengeID to its owner
        owners[challengeID] = owner;
        // Map the challengeID to the associated domain
        domains[challengeID] = domain;
        // Emit HTTPChallengeInitialized event
        emit HTTPChallengeInitialized(challengeID, owner, domain);
    }

    /**
     * @notice Get the challenge URL of an initialized HTTP challenge
     * @param challengeID uint256 challenge ID
     * @return string the challenge URL that the challenge HTML should be uploaded to
     */
    function _getChallengeURL(uint256 challengeID) private view returns (string memory) {
        // Challenge URL: declared_domain/_challengeID.html
        return string(abi.encodePacked(domains[challengeID], "/_", owners[challengeID], ".html"));
    }

    /**
     * @notice Get the detail of an initialized HTTP challenge
     * @param challengeID uint256 challenge ID
     * @return (string, string) the first parameters is the challenge URL that the HTML should be uploaded to,
     * and the second parameter is the challenge HTML string to be uploaded to the challenge URL
     */
    function getChallenge(uint256 challengeID) public view returns (string memory, string memory) {
        // URL: declared_domain/_challengeID.html
        string memory requiredURL = _getChallengeURL(challengeID);
        // HTML content must return the address of the declared controller of the domain
        string memory challengeHTML = string(abi.encodePacked(HTTPPrefix, owners[challengeID], HTTPSuffix));
        return (requiredURL, challengeHTML);
    }

     /**
     * @notice Get the Ethereum cost for each attempt in solving the HTTP challenge that MUST be sent
     * together when calling the solveChallenge method
     * @return uint the Ethereum cost in Wei
     */
    function _getProvableCost() internal returns (uint256) {
        return provable_getPrice("URL", GAS_LIMIT);
    }

    /**
     * @notice Solve the HTTP challenge
     * @param challengeId uint256 challenge ID
     */
    function solveChallenge(uint256 challengeId) public payable {
        // Check if the Ether sent can cover the cost required by Provable
        require(msg.value >= _getProvableCost(), "HTTPChallenge: insufficient funds");
        // Provable query
        string memory queryURL = string(abi.encodePacked("html(", _getChallengeURL(challengeId), ").xpath(//body)"));
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
        // Check if the ID has to be processed
        uint256 challengeId = provableIds[queryId];
        require(challengeId != 0, "HTTPChallenge: specified challenge cannot be found");
        require(!status[challengeId], "HTTPChallenge: specified challenge is already completed");
        // Check if the result is as expected which is the address of the declared controller
        if (keccak256(abi.encodePacked(result)) != keccak256(abi.encodePacked(owners[challengeId]))) {
            // Emit HTTPChallengeFailed
            emit HTTPChallengeFailed(challengeId, proof);
            // Failed validation, call _callbackChild
            _callbackChild(challengeId, false);
        }
        // Successful validation, completing the challenge
        status[challengeId] = true;
        emit HTTPChallengeSucceed(challengeId, proof);
        _callbackChild(challengeId, true);
    }

    /**
     * @notice Secondary callback function that can be implemented by child contract
     * @param challengeId uint256 challenge ID
     * @param validated bool validation status of the challenge
     */
    function _callbackChild(uint256 challengeId, bool validated) internal;

}