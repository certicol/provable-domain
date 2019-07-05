pragma solidity 0.5.3;

import "../node_modules/provable-eth-api/provableAPI.sol";

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
    event HTTPChallengeFailed(uint256 indexed challengeId);
    /// Event that will be emitted upon solving a HTTP challenge
    event HTTPChallengeSucceed(uint256 indexed challengeId);

    /**
     * @notice Initialize the contract
     * @param gasLimit uint256 maximum gas that the _callback function would consumes
     */
    constructor(uint256 gasLimit) {
        // Demand TLSNotary proof from Provable
        provable_setProof(proofType_TLSNotary | proofStorage_IPFS);
        // Set gas limit
        GAS_LIMIT = gasLimit;
    }

     /**
     * @notice Initialize a HTTP challenge
     * @param owner address address that declared that they control the domain
     * @param domain string domain controlled by the owner
     * @return uint256 the challenge ID
     */
    function initChallenge(address owner, string domain) internal returns (uint256) {
        // Create an unique challengeID for each challenge
        uint256 challengeID = uint256(keccak256(abi.encodePacked(owner, domain, block.number)));
        // Map the challengeID to its owner
        owners[challengeID] = owner;
        // Map the challengeID to the associated domain
        domains[challengeID] = domain;
        // Emit HTTPChallengeInitialized event
        emit HTTPChallengeInitialized(challengeID, owner, domain);
        // Return the challenge ID
        return challengeID;
    }

    /**
     * @notice Get the challenge URL of an initialized HTTP challenge
     * @param challengeID uint256 challenge ID
     * @return string the challenge URL that the challenge HTML should be uploaded to
     */
    function _getChallengeURL(uint256 challengeID) private view returns (string) {
        // Challenge URL: declared_domain/_challengeID.html
        return string(abi.encodePacked(domains[challengeID], "/_", owners[challengeID], ".html"));
    }

    /**
     * @notice Get the detail of an initialized HTTP challenge
     * @param challengeID uint256 challenge ID
     * @return (string, string) the first parameters is the challenge URL that the HTML should be uploaded to,
     * and the second parameter is the challenge HTML string to be uploaded to the challenge URL
     */
    function getChallenge(uint256 challengeID) public view returns (string, string) {
        // URL: declared_domain/_challengeID.html
        string requiredURL = _getChallengeURL(challengeID);
        // HTML content must return the address of the declared controller of the domain
        string challengeHTML = string(abi.encodePacked(HTTPPrefix, owners[challengeID], HTTPSuffix));
        return (requiredURL, challengeHTML);
    }

     /**
     * @notice Get the Ethereum cost for each attempt in solving the HTTP challenge that MUST be sent
     * together when calling the solveChallenge method
     * @return uint the Ethereum cost in Wei
     */
    function getProvableCost() public view returns (uint256) {
        return provable_getPrice("URL", GAS_LIMIT);
    }

    /**
     * @notice Solve the HTTP challenge
     * @param challengeID uint256 challenge ID
     */
    function solveChallenge(uint256 challengeId) public payable {
        // Check if the Ether sent can cover the cost required by Provable
        require(msg.value >= getProvableCost(), "HTTPChallenge: insufficient funds");
        // Provable query
        string queryURL = string(abi.encodePacked("html(", _getChallengeURL(challengeId), ").xpath(//body)"));
        bytes32 queryId = provable_query("URL", queryURL, GAS_LIMIT);
        // Record the queryId
        provableIds[queryId] = challengeId;
    }

    /**
     * @notice Callback function used by Provable
     * @param queryId bytes32 Provable query ID
     * @param result string result of the query
     * @dev implementing _callbackChild method would allow any child contract to take further actions once the verification is successful
     */
    function _callback(bytes32 queryId, string result) external {
        // Check if the msg.sender is Provable
        require(msg.sender == provable_cbAddress(), "HTTPChallenge: _callback can only be called by Provable");
        // Check if the ID has to be processed
        uint256 challengeId = provableIds[queryId];
        require(challengeId != 0, "HTTPChallenge: specified challenge cannot be found");
        require(!status[challengeId], "HTTPChallenge: specified challenge is already completed");
        // Check if the result is as expected which is the address of the declared controller
        if (result != string(owners[challengeId])) {
            // Emit HTTPChallengeFailed
            emit HTTPChallengeFailed(challengeId);
            // Failed validation, call _callbackChild
            _callbackChild(challengeId, false);
        }
        // Successful validation, completing the challenge
        status[challengeId] = true;
        emit HTTPChallengeSucceed(challengeId);
        _callbackChild(challengeId, true);
    }

    /**
     * @notice Secondary callback function that can be implemented by child contract
     * @param challengeID uint256 challenge ID
     * @param status string validation status of the challenge
     */
    function _callbackChild(uint256 challengeId, bool status) internal;

}