const { assert, expect } = require("chai")
const { network, deployments, ethers, getNamedAccounts } = require("hardhat")

describe("Cacao", () => {
    let Cacao, Fbayc, Delegator, borrowerCacao
    let deployer, lender, borrower
    let tokenId, price, duration, collection, fee, offerId, amount

    beforeEach(async () => {
        const accounts = await ethers.getSigners()
        deployer = accounts[0]
        // lender = accounts[1]
        borrower = accounts[2]
        hacker = accounts[3]
        await deployments.fixture(["all"])

        Cacao = await ethers.getContract("Cacao", deployer)
        CacaoVault = await ethers.getContract("CacaoVault", deployer)
        Fbayc = await ethers.getContract("FakeBoredApeYachtClub", deployer)
        Delegator = await ethers.getContract(
            "DelegationRegistry",
            CacaoVault.address
        )

        await CacaoVault.setMarketplaceAddress(Cacao.address)

        collection = Fbayc.address
        tokenId = 0
        utilityTokenId = 1
        price = ethers.utils.parseEther("1")
        duration = 86400
        fee = 3
        offerId = 1
        amount = 1
        borrowerCacao = Cacao.connect(borrower)
    })

    describe("createOffer", () => {
        beforeEach(async () => {
            await Fbayc.safeMint(amount, deployer.address)
            await Fbayc.setApprovalForAll(CacaoVault.address, true)
        })

        it("reverts if offer already exists", async () => {
            await Cacao.createOffer(price, tokenId, collection, duration)
            const anotherTx = Cacao.createOffer(
                price,
                tokenId,
                collection,
                duration
            )
            await expect(anotherTx).to.be.revertedWithCustomError(
                Cacao,
                "Cacao__OfferExists"
            )
        })

        it("reverts if offer price set is 0", async () => {
            price = 0
            const tx = Cacao.createOffer(price, tokenId, collection, duration)
            await expect(tx).to.be.revertedWithCustomError(
                Cacao,
                "Cacao__WrongInput"
            )
        })

        it("reverts if duration set is less than 1 day", async () => {
            duration = 0
            const tx = Cacao.createOffer(price, tokenId, collection, duration)
            await expect(tx).to.be.revertedWithCustomError(
                Cacao,
                "Cacao__WrongInput"
            )
        })

        it("adds new offer to offers[]", async () => {
            expect((await Cacao.getAllOffers()).length).to.be.equal(1)
            await Cacao.createOffer(price, tokenId, collection, duration)
            expect((await Cacao.getAllOffers()).length).to.be.equal(2)
        })

        it("properly initialized offer data", async () => {
            await Cacao.createOffer(price, tokenId, collection, duration)
            const timestamp = (await ethers.provider.getBlock()).timestamp
            const offer = await Cacao.getOfferById(offerId)
            expect(offer.offerId).equal(1)
            expect(offer.tokenId).equal(tokenId)
            expect(offer.price).equal(price)
            expect(offer.startTime).equal(timestamp)
            expect(offer.duration).equal(duration)
            expect(offer.collection).equal(Fbayc.address)
            expect(offer.lender).equal(deployer.address)
            expect(offer.borrower).equal(deployer.address)
            expect(offer.status).equal(1)
            expect(offer.utilityTokenId).equal(1)
        })

        it("deposits NFT, mints U-token and initializes data", async () => {
            await Cacao.createOffer(price, tokenId, collection, duration)
            expect(await Fbayc.ownerOf(tokenId)).to.be.equal(CacaoVault.address)
            const offer = await Cacao.getOfferById(offerId)
            expect(offer.utilityTokenId).equal(1)
            expect(await CacaoVault.ownerOf(tokenId)).equal(deployer.address)
        })

        it("adds new offer to offerByLender mapping", async () => {
            expect(
                (await Cacao.getOfferByLender(deployer.address)).length
            ).to.be.equal(0)
            await Cacao.createOffer(price, tokenId, collection, duration)
            expect(
                (await Cacao.getOfferByLender(deployer.address)).length
            ).to.be.equal(1)
        })

        it("emits OfferCreated event", async () => {
            const tx = Cacao.createOffer(price, tokenId, collection, duration)
            await expect(tx).to.emit(Cacao, "OfferCreated")
        })

        it("offerCounter increments after offer created", async () => {
            expect(await Cacao.offerCounter()).to.be.equal(1)
            await Cacao.createOffer(price, tokenId, collection, duration)
            expect(await Cacao.offerCounter()).to.be.equal(2)
        })
    })

    describe("acceptOffer", () => {
        beforeEach(async () => {
            await Fbayc.safeMint(amount, deployer.address)
            await Fbayc.setApprovalForAll(CacaoVault.address, true)
            await Cacao.createOffer(price, tokenId, collection, duration)
        })

        it("reverts accept call if offer status != OfferStatus.AVALIABLE", async () => {
            await borrowerCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })
            await expect(
                borrowerCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                    value: price,
                })
            ).to.be.revertedWithCustomError(Cacao, "Cacao__OfferNotAvailable")
        })

        it("reverts if borrower didnt sent enough funds", async () => {
            await expect(
                borrowerCacao.acceptOffer(Fbayc.address, tokenId, offerId)
            ).to.be.revertedWithCustomError(Cacao, "Cacao__NotEnoughFunds")
        })

        it("reverts if collection is 0 address", async () => {
            await expect(
                borrowerCacao.acceptOffer(
                    ethers.constants.AddressZero,
                    tokenId,
                    offerId,
                    { value: price }
                )
            ).to.be.revertedWithCustomError(Cacao, "Cacao__WrongAddress")
        })

        it("transfers U-token to new borrower", async () => {
            console.log("works before accept")
            await borrowerCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })
            console.log("works after accept")
            const utilityTokenId = (await Cacao.getOfferById(offerId))
                .utilityTokenId
            expect(await CacaoVault.ownerOf(utilityTokenId)).equal(
                borrower.address
            )
        })

        it("check if delegation was successful", async () => {
            await borrowerCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })
            expect(
                await Delegator.checkDelegateForToken(
                    borrower.address,
                    CacaoVault.address,
                    Fbayc.address,
                    tokenId
                )
            ).to.be.equal(true)
        })

        it("updates lenders balance", async () => {
            await borrowerCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })

            const balance = BigInt(price - (price * 3) / 100)
            expect(await Cacao.getEthBalance(deployer.address)).equal(balance)
        })

        it("taking the fee and updates the marketplace balance", async () => {
            await borrowerCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })

            const balance = BigInt((price * 3) / 100)
            expect(await Cacao.getEthBalance(Cacao.address)).equal(balance)
        })

        it("updates offer status to offerStatus.EXECUTED", async () => {
            await borrowerCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })
            expect((await Cacao.getOfferById(offerId)).status).equal(2)
        })

        it("emits OfferAccepted event", async () => {
            const tx = borrowerCacao.acceptOffer(
                Fbayc.address,
                tokenId,
                offerId,
                {
                    value: price,
                }
            )
            await expect(tx).to.emit(Cacao, "OfferAccepted")
        })
    })

    describe("cancelOffer", () => {
        beforeEach(async () => {
            await Fbayc.safeMint(amount, deployer.address)
            await Fbayc.setApprovalForAll(CacaoVault.address, true)
            await Cacao.createOffer(price, tokenId, collection, duration)
        })

        it("reverts if offer doesn't exist", async () => {
            offerId = 5
            await expect(Cacao.cancelOffer(Fbayc.address, tokenId, offerId)).to
                .be.reverted
        })

        it("reverts if called by NOT NFT owner", async () => {
            offerId = 0
            await expect(
                borrowerCacao.cancelOffer(Fbayc.address, tokenId, offerId)
            ).to.be.revertedWithCustomError(Cacao, "Cacao__NotOwner")
        })

        it("reverts cancel call if offer status != OfferStatus.AVAILABLE", async () => {
            await borrowerCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })
            await expect(
                Cacao.cancelOffer(Fbayc.address, tokenId, offerId)
            ).to.be.revertedWithCustomError(Cacao, "Cacao__OfferNotAvailable")
        })

        it("changes offer status to OfferStatus.CANCELED", async () => {
            await Cacao.cancelOffer(Fbayc.address, tokenId, offerId)
            const offer = await Cacao.getOfferById(offerId)
            expect(offer.status).equal(3)
        })

        it("deletes offer data from quick access mapping", async () => {
            await Cacao.cancelOffer(Fbayc.address, tokenId, offerId)
            expect(await Cacao.getOfferByTokenId(collection, tokenId)).equal(0)
        })

        it("emits OfferCanceled event", async () => {
            await expect(
                Cacao.cancelOffer(Fbayc.address, tokenId, offerId)
            ).to.emit(Cacao, "OfferCanceled")
        })
    })

    describe("withdrawNft", () => {
        beforeEach(async () => {
            await Fbayc.safeMint(amount, deployer.address)
            await Fbayc.setApprovalForAll(CacaoVault.address, true)
            await Cacao.createOffer(price, tokenId, collection, duration)
            await borrowerCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })
        })

        it("reverts if offer is still active", async () => {
            await expect(
                Cacao.withdrawNft(collection, tokenId)
            ).to.be.revertedWithCustomError(Cacao, "Cacao__OfferIsActive")
        })

        it("reverts if called by not NFT owner", async () => {
            await network.provider.send("evm_increaseTime", [duration])
            await expect(
                borrowerCacao.withdrawNft(collection, tokenId)
            ).to.be.revertedWithCustomError(Cacao, "Cacao__NotOwner")
        })

        it("deletes mapping for quick access prior to withdrawal", async () => {
            await network.provider.send("evm_increaseTime", [duration])
            await Cacao.withdrawNft(collection, tokenId)
            expect(await Cacao.getOfferByTokenId(collection, tokenId)).equal(0)
        })

        it("transfer NFT back to the owner", async () => {
            await network.provider.send("evm_increaseTime", [duration])
            await Cacao.withdrawNft(collection, tokenId)
            expect(await Fbayc.ownerOf(tokenId)).equal(deployer.address)
        })
    })
})
