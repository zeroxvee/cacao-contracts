// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IDelegationRegistry.sol";
import "./CacaoVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

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
error Cacao__OfferExists();
error Cacao__WrongInput();
error Cacao__NotOwner();
error Cacao__OfferNotAvailable();
error Cacao__WrongAddress();

/*
*   @dev cacao v1.0
*/
contract Cacao is Ownable {
    enum OfferStatus {
        NOT_INITIATED,
        AVALIABLE,
        EXECUTED,
        CANCELED,
        COMPLETED
    }

    address public delegationRegistry;
    address public cacaoVault;
    uint256 public offerCounter;

    // 0 - 10%
    uint256 public fee;

    // Offers object
    struct Offer {
        uint256 offerId;
        uint256 tokenId;
        uint256 price;
        uint256 startTime;
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

    // keeping track of Lenders and Marketplace balances
    mapping(address => uint256) balances;

    // mapping for quick checks whether offer was already created
    // 0 - deactive/not created, any other # - offerID
    mapping(address => mapping(uint256 => uint256)) tokenToOfferId;

    event OfferCreated(
        uint256 id,
        uint256 price,
        uint256 tokenId,
        address collection,
        uint256 duration,
        address lender
    );

    event OfferAccepted(
        uint256 id,
        address vault,
        address delegate,
        address contract,
        uint256 tokenId,
        bool value
    );

    event OfferCancelled(address collection, uint256 tokenId, uint256 offerId);

    constructor(
        address _delegationRegistry,
        address _cacaoVault,
        uint256 _fee
    ) {
        delegationRegistry = _delegationRegistry;
        cacaoVault = _cacaoVault;
        fee = _fee;
    }

    ////////////////////////*** WRITE *** ///////////////////////
    /////////////////////////////////////////////////////////////

    function createOffer(
        uint256 _price,
        uint256 _tokenId,
        address _collection,
        uint256 _duration
    ) public {
        //
        // TODO: add reentrancy protection
        //
        if (tokenToOfferId[_collection][_tokenId]) {
            revert Cacao__OfferExists();
        }
        if (_price == 0) {
            revert Cacao__WrongInput();
        }
        if (_duration < 1 days) {
            revert Cacao__WrongInput();
        }

        IERC721(_collection).transferFrom(msg.sender, cacaoVault, _tokenId);
        Offer memory newOffer = Offer({
            offerId: offerCounter,
            tokenId: _tokenId,
            price: _price,
            startTime: block.timestamp,
            duration: _duration,
            collection: _collection,
            lender: msg.sender,
            borrower: address(0),
            status: OfferStatus.AVALIABLE
        });
                tokenToOfferId[_collection][_tokenId] = offerCounter;
        offers.push(newOffer);
        offersByLender[msg.sender].push(newOffer);

        /*
        / Might be used for offer value updates later
        */
        emit OfferCreated(
            offerCounter,
            _price,
            _tokenId,
            _collection,
            _duration,
            msg.sender
        );
        offerCounter++;
    }

    function cancelOffer(address _collection, uint256 _tokenId, uint256 _offerId) public {
        Offer memory offer = offers[_offerId]
        if (offerCounter > _offerId) {
            revert Cacao__OfferNotAvailable();
        }
        if (offer.lender != msg.sender) {
            revert Cacao__NotOwner();
        }
        if (offer.status == OfferStatus.AVALIABLE) {
            revert Cacao__OfferNotAvailable();
        }

        offer.status = OfferStatus.CANCELED;
        delete tokenToOfferId[_collection][_tokenId];
        emit OfferCancelled(_collection, _tokenId,_offerId);
    }

    function acceptOffer(
        address _collection,
        uint256 _tokenId,
        uint256 offerId
    ) public payable {
        Offer memory offer = offers[_offerId]
        if (offer.status != OfferStatus.AVALIABLE) {
            revert Cacao__OfferNotAvailable();
        }
        if (offer.price > msg.value) {
            revert Cacao__NotEnoughFunds();
        }
        if (_collection == address(0)) {
            revert Cacao__WrongAddress();
        }

        bool value = true;
        IDelegationRegistry(delegationRegistry).delegateForToken(
            msg.sender,
            _collection,
            _tokenId,
            value
        );

        uint256 paymentFee = (msg.value * fee) / 100;
        balances[offer.lender] += (msg.value - paymentFee);
        balances[address(this)] += paymentFee;
        offer.status = OfferStatus.EXECUTED;
        emit OfferAccepted(
            offerId,
            msg.sender,
            offer.lender,
            _collection,
            _tokenId,
            value
        );
    }

    /*
    /  Not sure if we are going to need this since it's way harder to implement
    /  multiple transfer and offer creation
    */
    // function delegateForAll(address _delegate) public {
    //     bool value = true;
    //     delegationRegistry.delegateForAll(_delegate, value);
    // }

    // also will remove this for now
    //
    // function delegateForContract(address _delegate, address _contract) public {
    //     bool value = true;
    //     delegationRegistry.delegateForContract(_delegate, _contract, value);
    // }

    /*
    /   also not sure if we'll need this but leave it here for now
    */
    // function revokeDelegate(address _delegate) public {
    //     delegationRegistry.revokeDelegate(_delegate);
    // }

    function withdrawFees() public onlyOwner {
        uint256 balance = balances[address(this)];
        _withdraw(balance);
    }

    function withdrawByLender() public {
        uint256 balance = balances[msg.sender];
        _withdraw(balance);
    }

    /*
     *   Add security check, only owner of NFT can withdraw
     *   only can withdraw if deal has been completed
     */
    function withdrawNft(address _collection, uint256 _tokenId) public {
        IERC721 collection = IERC721(_collection);
        collection.safeTransferFrom(address(this), msg.sender, _tokenId);
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
            result = IDelegationRegistry(delegationRegistry)
                .checkDelegateForToken(_delegate, _vault, _contract, tokenId);
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
