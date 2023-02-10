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

contract Cacao is Ownable {
    enum OfferStatus {
        NOT_INITIATED,
        AVALIABLE,
        EXECUTED,
        CANCELED,
        COMPLETED
    }

    IDelegationRegistry public delegationRegistry;
    CacaoVault public cacaoVault;
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

    // keeping track of Lenders and Marketplace balances
    mapping(address => uint256) balances;

    // mapping for quick checks whether offer was already created
    mapping(address => mapping(uint256 => bool)) collectionToToken;

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

    event OfferCancelled();

    event OfferExecuted();

    constructor(address _delegationRegistry, address _cacaoVault) {
        delegationRegistry = IDelegationRegistry(_delegationRegistry);
        cacaoVault = CacaoVault(_cacaoVault);
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
        if (collectionToToken[_collection][_tokenId]) {
            revert Cacao__OfferExists();
        }
        if (_price == 0) {
            revert Cacao__NotEnoughFunds();
        }
        if (_duration < 1 days) {
            revert Cacao__WrongInput();
        }
        IERC721 collection = IERC721(_collection);
        address nftOwner = collection.ownerOf(_tokenId);
        if (nftOwner != address(0)) {
            revert Cacao__WrongInput();
        }
        if (nftOwner != msg.sender) {
            revert Cacao__NotOwner();
        }
        collection.approve(address(cacaoVault), _tokenId);
        collection.safeTransferFrom(msg.sender, address(cacaoVault), _tokenId);
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

        /*
        / Might be used for offer value updates later
        */
        emit OfferCreated(_price, _tokenId, _collection, _duration, msg.sender);
    }

    function cancelOffer(uint256 _offerId) public {
        if (offerCounter > _offerId) {
            revert Cacao__OfferNotAvailable();
        }
        if (offers[_offerId].lender != msg.sender) {
            revert Cacao__NotOwner();
        }
        if (offers[_offerId].status == OfferStatus.AVALIABLE) {
            revert Cacao__OfferNotAvailable();
        }
        offers[_offerId].status = OfferStatus.CANCELED;
    }

    function delegateForToken(
        address _delegate,
        address _collection,
        uint256 _tokenId,
        uint256 offerId
    ) public payable {
        if (offers[offerId].status != OfferStatus.AVALIABLE) {
            revert Cacao__WrongIdNumber();
        }
        if (offers[offerId].price <= msg.value) {
            revert Cacao__NotEnoughFunds();
        }
        if (_collection != address(0) && _delegate != address(0)) {
            revert Cacao__WrongAddress();
        }
        IERC721 collection = IERC721(_collection);
        address nftOwner = collection.ownerOf(_tokenId);
        if (nftOwner != msg.sender) {
            revert Cacao__NotOwner();
        }

        bool value = true;
        delegationRegistry.delegateForToken(
            _delegate,
            _collection,
            _tokenId,
            value
        );

        balances[msg.sender] += msg.value;
        offers[offerId].status = OfferStatus.EXECUTED;
        emit DelegateForToken(
            msg.sender,
            _delegate,
            _collection,
            _tokenId,
            value
        );
    }

    /*
    /*  Not sure if we are going to need this since it's way harder to implement
    /*  multiple transfer and offer creation
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
