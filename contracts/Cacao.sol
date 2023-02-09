// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IDelegationRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*TODO:  1. Write funciton that recevies info out of contract to invoke delegateForToken
 *       2. keep all the active offers that are being delegated
 *       3. make all the functions requirements that keep ETH, track time
 *       4. If delegation was stopped by the Lender, then ETH returned to the borrower
 *       5. after delegation time has passed, Lender can withdraw his 90%, 10% will stay or transfered to Cacao.
 *       6. Implement Royalties so NFT authors also benefit from every rent.
 *
 */
error Cacao__WrongIdNumber();
error Cacao__NotEnoughFunds();
error Cacao__TransferFailed();

contract Cacao is Ownable {
    enum OfferStatus {
        NOT_INITIATED,
        AVALIABLE,
        EXECUTED,
        CANCELED,
        COMPLETED
    }

    IDelegationRegistry public delegationRegistry;
    uint256 public offerCounter;
    uint256 public fee;

    // Offers object
    struct Offer {
        uint256 offerId;
        uint256 tokenId;
        uint256 price;
        uint256 duration;
        address collection;
        address lender;
        address borrower;
        OfferStatus status;
    }

    // array of all offers on the marketplace
    Offer[] public offers;

    // delegations
    // mapping(address => mapping ()=> uint256)) public offers;
    mapping(address => Offer[]) offersByLender;

    mapping(address => uint256) balances;

    event OfferCreated(
        uint256 price,
        uint256 tokenId,
        address collection,
        uint256 duration,
        address lender
    );

    event DelegateForToken(
        address vault,
        address delegate,
        address contract_,
        uint256 tokenId,
        bool value
    );

    constructor(address _delegationRegistry) {
        delegationRegistry = IDelegationRegistry(_delegationRegistry);
    }

    ////////////////////////*** WRITE *** ///////////////////////
    /////////////////////////////////////////////////////////////

    function createOffer(
        uint256 _price,
        uint256 _tokenId,
        address _collection,
        uint256 _duration
    ) public {
        Offer memory newOffer = Offer({
            offerId: offerCounter,
            tokenId: _tokenId,
            price: _price,
            duration: _duration,
            collection: _collection,
            lender: msg.sender,
            borrower: address(0),
            status: OfferStatus.AVALIABLE
        });
        offers.push(newOffer);
        offersByLender[msg.sender].push(newOffer);

        offerCounter++;
        emit OfferCreated(_price, _tokenId, _collection, _duration, msg.sender);
    }

    function cancelOffer(uint256 _offerId) public {
        offers[_offerId].status = OfferStatus.CANCELED;
    }

    function delegateForToken(
        address _delegate,
        address _contract,
        uint256 _tokenId,
        uint256 offerId
    ) public payable {
        if (offers[offerId].status != OfferStatus.AVALIABLE) {
            revert Cacao__WrongIdNumber();
        }
        if (offers[offerId].price <= msg.value) {
            revert Cacao__NotEnoughFunds();
        }
        bool value = true;
        delegationRegistry.delegateForToken(
            _delegate,
            _contract,
            _tokenId,
            value
        );

        balances[msg.sender] += msg.value;
        offers[offerId].status = OfferStatus.EXECUTED;
        emit DelegateForToken(
            msg.sender,
            _delegate,
            _contract,
            _tokenId,
            value
        );
    }

    function delegateForAll(address _delegate) public {
        bool value = true;
        delegationRegistry.delegateForAll(_delegate, value);
    }

    function delegateForContract(address _delegate, address _contract) public {
        bool value = true;
        delegationRegistry.delegateForContract(_delegate, _contract, value);
    }

    function revokeDelegate(address _delegate) public {
        delegationRegistry.revokeDelegate(_delegate);
    }

    function withdrawFees() public onlyOwner {
        uint256 balance = balances[address(this)];
        _withdraw(balance);
    }

    function withdrawByVault() public {
        uint256 balance = balances[msg.sender];
        balances[address(this)] += (balance * fee) / 100;
        _withdraw(balance);
    }

    function _withdraw(uint256 balance) internal {
        balance = address(this).balance;
        if (balance == 0) {
            revert Cacao__NotEnoughFunds();
        }
        (bool callResult, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!callResult) revert Cacao__TransferFailed();
    }

    ////////////////////////*** READ *** ///////////////////////
    ////////////////////////////////////////////////////////////

    function checkDelegateForToken(
        address _delegate,
        address _vault,
        address _contract,
        uint256 tokenId
    ) public view returns (bool result) {
        return
            result = delegationRegistry.checkDelegateForToken(
                _delegate,
                _vault,
                _contract,
                tokenId
            );
    }

    function getAllOffers() public view returns (Offer[] memory) {
        return offers;
    }

    function getOfferByLender(
        address lender
    ) public view returns (Offer[] memory) {
        return offersByLender[lender];
    }
}
