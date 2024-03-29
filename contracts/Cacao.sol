// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IDelegationRegistry.sol";
import "./CacaoVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/*  TODO:
 *
 *  1. If delegation was stopped by the Lender, then some ETH returned to the borrower
 *  2. after delegation time has passed, Lender can withdraw his 90%, 10% will stay or transfered to Cacao.
 *  3. Implement Royalties so NFT authors also benefit from every rent.
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
error Cacao__OfferIsActive();

/**
 * @title Cacao v1.0 - ERC721-U marketplace contract
 * @author @zeroxvee
 */
contract Cacao is Ownable {
    enum OfferStatus {
        NOT_INITIATED,
        AVAILABLE,
        EXECUTED,
        CANCELED,
        COMPLETED
    }

    address public delegationRegistry;
    address public cacaoVault;
    uint256 public offerCounter = 1;

    // Cacao Marketplace fee
    // 0 - 10%
    uint256 public fee;

    // fee for lenders who break the offer withour waiting till expiration
    // 10 - 50%
    uint256 public unexpiredOfferFee = 30;

    // Offers object
    struct Offer {
        uint256 offerId;
        uint256 tokenId;
        uint256 price;
        uint256 startTime;
        uint256 expiration;
        address collection;
        uint256 utilityTokenId;
        address lender;
        address borrower;
        OfferStatus status;
    }

    // array of all offers on the marketplace
    Offer[] public offers;

    // delegations
    // mapping(address => mapping ()=> uint256)) public offers;
    mapping(address => Offer[]) offersByLender;

    // keeping track of Lenders, borrowers and Marketplace balances
    mapping(address => uint256) private balances;

    // mapping for quick checks whether offer was already created
    // NFT address => tokenId => offerId
    // 0 - canceled/not created, any other # - offerID
    mapping(address => mapping(uint256 => uint256)) tokenToOfferId;

    event OfferCreated(
        uint256 id,
        uint256 price,
        uint256 tokenId,
        address collection,
        uint256 expiration,
        address lender
    );

    event OfferAccepted(
        uint256 id,
        address borrower,
        address collection,
        uint256 tokenId
    );

    event OfferCanceled(address collection, uint256 tokenId, uint256 offerId);

    constructor(
        address _delegationRegistry,
        address _cacaoVault,
        uint256 _fee
    ) {
        delegationRegistry = _delegationRegistry;
        cacaoVault = _cacaoVault;
        fee = _fee;
        offers.push();
    }

    ////////////////////////*** WRITE *** ///////////////////////
    /////////////////////////////////////////////////////////////

    /**
     *
     * @param _price by lender in ETH
     * @param _tokenId tokenId of lended token
     * @param _collection address of lended NFT collection
     * @param _duration of the offer in seconds
     */
    function createOffer(
        uint256 _price,
        uint256 _tokenId,
        address _collection,
        uint256 _duration
    ) public {
        //
        // TODO: add reentrancy protection
        //
        if (tokenToOfferId[_collection][_tokenId] > 0) {
            revert Cacao__OfferExists();
        }
        if (_price == 0) {
            revert Cacao__WrongInput();
        }
        if (_duration < 1 days) {
            revert Cacao__WrongInput();
        }
        uint256 _expiration = block.timestamp + _duration;
        uint256 _utilityTokenId = CacaoVault(cacaoVault).depositToVault(
            _collection,
            _tokenId,
            _expiration,
            msg.sender
        );

        Offer memory newOffer = Offer({
            offerId: offerCounter,
            collection: _collection,
            tokenId: _tokenId,
            price: _price,
            startTime: block.timestamp,
            expiration: _expiration,
            lender: msg.sender,
            borrower: msg.sender,
            utilityTokenId: _utilityTokenId,
            status: OfferStatus.AVAILABLE
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
            _expiration,
            msg.sender
        );
        offerCounter++;
    }

    /**
     *
     * @notice cancel listed offer before it was accepted and therefore
     *         not charged any fees
     * @param _collection address of lended NFT collection
     * @param _tokenId token ID of lended token
     * @param _offerId listed offer ID
     */
    function cancelOffer(
        address _collection,
        uint256 _tokenId,
        uint256 _offerId
    ) public {
        Offer storage offer = offers[_offerId];
        if (offer.lender != msg.sender) {
            revert Cacao__NotOwner();
        }
        if (offer.status != OfferStatus.AVAILABLE) {
            revert Cacao__OfferNotAvailable();
        }

        offer.status = OfferStatus.CANCELED;
        delete tokenToOfferId[_collection][_tokenId];
        emit OfferCanceled(_collection, _tokenId, _offerId);
    }

    /**
     *
     * @notice accepts listed NFT-U offer on behalf of borrower
     * @param _collection address of borrowed NFT collection
     * @param _tokenId token ID of borrowed token
     * @param _offerId listed offer ID
     */
    function acceptOffer(
        address _collection,
        uint256 _tokenId,
        uint256 _offerId
    ) public payable {
        Offer storage offer = offers[_offerId];
        if (offer.status != OfferStatus.AVAILABLE) {
            revert Cacao__OfferNotAvailable();
        }
        if (offer.price > msg.value) {
            revert Cacao__NotEnoughFunds();
        }
        if (_collection == address(0)) {
            revert Cacao__WrongAddress();
        }

        CacaoVault(cacaoVault).transferFrom(
            offer.borrower,
            msg.sender,
            offer.utilityTokenId
        );

        // initial fees calculation in case if offer is completed without further actions
        // from lender or borrower
        uint256 cacaoFee = (offer.price * fee) / 100;
        balances[address(this)] += cacaoFee;
        balances[offer.lender] += offer.price - cacaoFee;

        // Tracking ETH for each lender to process on withdrawal later
        // balances[offer.lender] += msg.value;
        offer.status = OfferStatus.EXECUTED;
        emit OfferAccepted(_offerId, msg.sender, _collection, _tokenId);
    }

    /**
     *
     * @notice withdraw funds from the contract
     * can only be called by the contract owner
     */
    function withdrawFees() public onlyOwner {
        uint256 balance = balances[address(this)];
        _withdraw(msg.sender, balance);
    }

    /**
     *
     * @notice withdraw accumulated funds by lender/borrower
     */
    function withdrawByUser() public {
        uint256 balance = balances[msg.sender];
        _withdraw(msg.sender, balance);
    }

    /**
     *
     * @notice withdraw fx core
     * @param recipient address of funds recipient
     * @param balance balance in wei
     */
    function _withdraw(address recipient, uint256 balance) internal {
        balance = address(this).balance;
        if (balance == 0) {
            revert Cacao__NotEnoughFunds();
        }
        (bool callResult, ) = payable(recipient).call{
            value: address(this).balance
        }("");
        if (!callResult) revert Cacao__TransferFailed();
    }

    /**
     *
     * @notice sends NFT back to the lender and processing fees and balances
     * @param _collection address of NFT collection
     * @param _tokenId NFT token ID
     */
    function withdrawNft(address _collection, uint256 _tokenId) public {
        uint256 offerId = tokenToOfferId[_collection][_tokenId];
        Offer memory offer = offers[offerId];

        if (offer.lender != msg.sender) {
            revert Cacao__NotOwner();
        }

        // !! Add a user case if lender never takes his NFT
        // !! possibly process it when offer is created
        // !! and balance updated below here on withdrawal
        unchecked {
            uint256 duration = offer.expiration - offer.startTime;
            uint256 timePassed = block.timestamp - offer.startTime;

            // coefficient of the time past from total time, 0 - 100%
            uint256 coefficient = (timePassed * 100) / duration;

            // if coefficient >= 100, meaning the offer expired, then 0
            // otherwise extra fee of unexpiredOfferFee %
            uint256 incompleteOfferFee = coefficient >= 100
                ? 0
                : (offer.price * unexpiredOfferFee) / 100;

            // value for the actual time passed
            uint256 actualOfferValue = (offer.price * coefficient) / 100;

            // Cacao: taking fee only for the time offer lasted
            uint256 cacaoFee = (actualOfferValue * fee) / 100;

            // borrowers total refund for cancelation of active offer
            uint256 borrowerRefund = offer.price -
                actualOfferValue +
                incompleteOfferFee;

            // final amount for lender to withdraw later
            uint256 lenderFee = offer.price - borrowerRefund - cacaoFee;

            // removing initial precalculated fees from balances
            balances[offer.lender] -= offer.price - cacaoFee;
            balances[address(this)] -= cacaoFee;

            // updating balances
            balances[offer.lender] += lenderFee;
            balances[address(this)] += cacaoFee;
            balances[offer.borrower] += borrowerRefund;
        }

        delete tokenToOfferId[_collection][_tokenId];
        offer.status = OfferStatus.COMPLETED;
        CacaoVault(cacaoVault).withdrawNft(offer.utilityTokenId);
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

    function getOfferById(uint256 offerId) public view returns (Offer memory) {
        return offers[offerId];
    }

    function getOfferByTokenId(
        address collection,
        uint256 tokenId
    ) public view returns (uint256) {
        return tokenToOfferId[collection][tokenId];
    }

    function getEthBalance(address user) public view returns (uint256) {
        return balances[user];
    }
}
