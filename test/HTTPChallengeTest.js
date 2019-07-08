// Import library function
const { BN, expectEvent, expectRevert } = require('openzeppelin-test-helpers');
const { expect } = require('chai');

// Obtain contract abstractions
const HTTPChallengeTest = artifacts.require('HTTPChallengeTest');

// Test for CerttifyDAOToken.sol
contract('HTTPChallengeTest', function(accounts) {

    // Address seeking validation
    const requestAddress = web3.utils.toChecksumAddress(
        '0x' + web3.utils.keccak256('HTTPChallengeTest').substring(26)
    );
    const requestAddressFail = web3.utils.toChecksumAddress(
        '0x' + web3.utils.keccak256('HTTPChallengeTest.Fail').substring(26)
    );

    // Default gas price for Provable callback (10 GWei)
    const callbackGas = '10000000000';

    // Storing instance of deployed contract
    var contractInstance;

    // Deploy the contract before each test
    beforeEach(async function() {
        // Get the instance returned
        contractInstance = await HTTPChallengeTest.new({ from: accounts[1] });
        // Set the provider to WebsocketProvider to allow event subscription
        let currentHTTPProvider = web3.currentProvider.host;
        contractInstance.contract.setProvider(currentHTTPProvider.replace("http", "ws"));
        // Use up the first free request quota per contract
        let receipt = await contractInstance.initChallengeTest(requestAddressFail, 'https://provable-domain.test.org');
        let challengeId = receipt.logs[0].args.challengeId;
        await contractInstance.solveChallengeTest(challengeId, { value: 0 });
        await new Promise(function(resolve) {
            contractInstance.contract.events.HTTPChallengeFailed(
                function() {
                    resolve();
                }
            );
        });
    });

    it('should initialize HTTP challenge', async function() {
        let receipt = await contractInstance.initChallengeTest(requestAddress, 'https://provable-domain.test.org');
        expectEvent.inLogs(receipt.logs, 'HTTPChallengeInitialized', { owner: requestAddress, domain:'https://provable-domain.test.org' });
    });

    it('should return correct challenge URL and string', async function() {
        let receipt = await contractInstance.initChallengeTest(requestAddress, 'https://provable-domain.test.org');
        let challengeId = receipt.logs[0].args.challengeId;
        let challenge = await contractInstance.getChallenge(challengeId);
        expect(challenge['0']).to.have.string('https://provable-domain.test.org' + '/_' + requestAddress.substring(2).toLowerCase() + '.html');
        expect(challenge['1']).to.have.string('<html><body>' + requestAddress.substring(2).toLowerCase() + '</body></html>');
    });

    it('should return the cost for solveChallengeTest', async function() {
        let cost_1GWei = await contractInstance.getProvableCost.call('1000000000');
        expect(cost_1GWei).to.be.bignumber.to.be.above(new BN(0));
        let cost_2GWei = await contractInstance.getProvableCost.call('2000000000');
        expect(cost_2GWei).to.be.bignumber.to.be.above(cost_1GWei);
    });

    it('should complete HTTP challenge when the required URL is prepared as required', async function() {
        let receipt = await contractInstance.initChallengeTest(requestAddress, 'https://raw.githubusercontent.com/certicol/provable-domain/master/test/html');
        let challengeId = receipt.logs[0].args.challengeId;
        let cost = await contractInstance.getProvableCost.call(callbackGas);
        await contractInstance.solveChallengeTest(challengeId, { value: cost, gasPrice: callbackGas });
        let callbackTxHash = await new Promise(function(resolve, revert) {
            contractInstance.contract.events.HTTPChallengeSucceed(
                function(error, result) {
                    if (error) { revert(error); }
                    resolve(result.transactionHash);
                }
            );
        });
        await expectEvent.inTransaction(callbackTxHash, contractInstance.constructor, 'HTTPChallengeSucceed', { challengeId: challengeId });
    });

    it('should failed HTTP challenge when the required URL did not returned the correct string', async function() {
        let receipt = await contractInstance.initChallengeTest(requestAddressFail, 'https://raw.githubusercontent.com/certicol/provable-domain/master/test/html');
        let challengeId = receipt.logs[0].args.challengeId;
        let cost = await contractInstance.getProvableCost.call(callbackGas);
        await contractInstance.solveChallengeTest(challengeId, { value: cost, gasPrice: callbackGas });
        let callbackTxHash = await new Promise(function(resolve, revert) {
            contractInstance.contract.events.HTTPChallengeFailed(
                function(error, result) {
                    if (error) { revert(error); }
                    resolve(result.transactionHash);
                }
            );
        });
        await expectEvent.inTransaction(callbackTxHash, contractInstance.constructor, 'HTTPChallengeFailed', { challengeId: challengeId });
    });

    it('should failed HTTP challenge when the required URL does not exist', async function() {
        let receipt = await contractInstance.initChallengeTest(requestAddressFail, 'https://provable-domain.test.not.exist.org');
        let challengeId = receipt.logs[0].args.challengeId;
        let cost = await contractInstance.getProvableCost.call(callbackGas);
        await contractInstance.solveChallengeTest(challengeId, { value: cost, gasPrice: callbackGas });
        let callbackTxHash = await new Promise(function(resolve, revert) {
            contractInstance.contract.events.HTTPChallengeFailed(
                function(error, result) {
                    if (error) { revert(error); }
                    resolve(result.transactionHash);
                }
            );
        });
        await expectEvent.inTransaction(callbackTxHash, contractInstance.constructor, 'HTTPChallengeFailed', { challengeId: challengeId });
    });

    it('should revert when solveChallengeTest is called without sufficient Ethereum', async function() {
        let receipt = await contractInstance.initChallengeTest(requestAddressFail, 'https://raw.githubusercontent.com/certicol/provable-domain/master/test/html');
        let challengeId = receipt.logs[0].args.challengeId;
        let cost = await contractInstance.getProvableCost.call(callbackGas);
        await expectRevert(contractInstance.solveChallengeTest(challengeId, { value: cost.sub(new BN(1)), gasPrice: callbackGas }), "HTTPChallenge: incorrect funds sent");
    });

    it('should revert when solveChallengeTest is called with too much Ethereum', async function() {
        let receipt = await contractInstance.initChallengeTest(requestAddressFail, 'https://raw.githubusercontent.com/certicol/provable-domain/master/test/html');
        let challengeId = receipt.logs[0].args.challengeId;
        let cost = await contractInstance.getProvableCost.call(callbackGas);
        await expectRevert(contractInstance.solveChallengeTest(challengeId, { value: cost.add(new BN(1)), gasPrice: callbackGas }), "HTTPChallenge: incorrect funds sent");
    });

    it('should revert when solveChallengeTest is called with Ethereum from an estimated cost using a different gas price', async function() {
        let receipt = await contractInstance.initChallengeTest(requestAddressFail, 'https://raw.githubusercontent.com/certicol/provable-domain/master/test/html');
        let challengeId = receipt.logs[0].args.challengeId;
        // Cost estimation using 10 GWei
        let cost = await contractInstance.getProvableCost.call(callbackGas);
        // Call using 100 GWei - too little Ethereum is sent in this case
        await expectRevert(contractInstance.solveChallengeTest(challengeId, { value: cost.sub(new BN(1)), gasPrice: '100000000000' }), "HTTPChallenge: incorrect funds sent");
        // Call using 1 GWei - too much Ethereum is sent in this case
        await expectRevert(contractInstance.solveChallengeTest(challengeId, { value: cost.sub(new BN(1)), gasPrice: '1000000000' }), "HTTPChallenge: incorrect funds sent");
    });

    it('should revert when completed challenge is validated again', async function() {
        let receipt = await contractInstance.initChallengeTest(requestAddress, 'https://raw.githubusercontent.com/certicol/provable-domain/master/test/html');
        let challengeId = receipt.logs[0].args.challengeId;
        let cost = await contractInstance.getProvableCost.call(callbackGas);
        await contractInstance.solveChallengeTest(challengeId, { value: cost, gasPrice: callbackGas });
        await new Promise(function(resolve) {
            contractInstance.contract.events.HTTPChallengeSucceed(
                function() {
                    resolve();
                }
            );
        });
        await expectRevert(contractInstance.solveChallengeTest(challengeId, { value: cost, gasPrice: callbackGas }), "HTTPChallenge: specified challenge is already completed");
    });

    it('should revert when __callback is called by address other than provable', async function() {
        await expectRevert(
            contractInstance.__callback(
                "0xe855bb4c9f942bc7e83c1713fd5be65d747a37a666691f197dcf651141402030",
                "",
                "0x"
            ), "HTTPChallenge: _callback can only be called by Provable"
        );
    });

});