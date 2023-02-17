const { assert, expect } = require("chai")
const { network, deployments, ethers, getNamedAccounts } = require("hardhat")

describe("Cacao", () => {
    let Cacao, Fbayc, Delegator
    let deployer, lender, borrower
    let tokenId, price, duration, collection, fee

    beforeEach(async () => {
        const accounts = await ethers.getSigners()
        deployer = accounts[0]
        lender = accounts[1]
        borrower = accounts[2]
        hacker = accounts[3]
        await deployments.fixture(["all"])

        Delegator = await ethers.getContract("DelegationRegistry", deployer)
        Cacao = await ethers.getContract("Cacao", deployer)
        CacaoVault = await ethers.getContract("CacaoVault", deployer)
        Fbayc = await ethers.getContract("FakeBoredApeYachtClub", deployer)

        collection = Fbayc.address
        tokenId = 0
        price = ethers.utils.parseEther("1")
        duration = 86400
        fee = 3
    })

    describe("createOffer", () => {
        beforeEach(async () => {
            await Fbayc.safeMint(deployer.address)
            await Fbayc.setApprovalForAll(Cacao.address, true)
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
            expect((await Cacao.getAllOffers()).length).to.be.equal(0)
            await Cacao.createOffer(price, tokenId, collection, duration)
            expect((await Cacao.getAllOffers()).length).to.be.equal(1)
        })

        it("properly initialized offer data", async () => {
            const offerId = 0
            await Cacao.createOffer(price, tokenId, collection, duration)
            const offer = await Cacao.getOfferById(offerId)

            expect(offer.offerId).equal(1)
            expect(offer.tokenId).equal(tokenId)
            expect(offer.price).equal(price)
            // it("initialized block.timestamp", async() => {
            //     expect(offer.offerId).equal(1)
            //     ethers.utils.t
            // })
            expect(offer.duration).equal(duration)
            expect(offer.collection).equal(Fbayc.address)
            expect(offer.lender).equal(deployer.address)
            expect(offer.borrower).equal(ethers.constants.AddressZero)
            expect(offer.status).equal(1)
        })

        it("transfers NFT asset to Cacao Vault", async () => {
            await Cacao.createOffer(price, tokenId, collection, duration)
            expect(await Fbayc.ownerOf(tokenId)).to.be.equal(CacaoVault.address)
        })

        it("transfers NFT asset to Cacao Vault", async () => {
            await Cacao.createOffer(price, tokenId, collection, duration)
            expect(await Fbayc.ownerOf(tokenId)).to.be.equal(CacaoVault.address)
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
            await Fbayc.safeMint(deployer.address)
            await Fbayc.setApprovalForAll(Cacao.address, true)
            await Cacao.createOffer(price, tokenId, collection, duration)
        })

        it("reverts if offer status != OfferStatus.AVALIABLE", async () => {
            const offerId = 0
            const newCacao = Cacao.connect(borrower)
            await newCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })
            await expect(
                newCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                    value: price,
                })
            ).to.be.revertedWithCustomError(Cacao, "Cacao__OfferNotAvailable")
        })

        it("reverts if borrower didnt sent enough funds", async () => {
            const offerId = 0
            const newCacao = Cacao.connect(borrower)
            await expect(
                newCacao.acceptOffer(Fbayc.address, tokenId, offerId)
            ).to.be.revertedWithCustomError(Cacao, "Cacao__NotEnoughFunds")
        })

        it("reverts if collection is 0 address", async () => {
            const offerId = 0
            const newCacao = Cacao.connect(borrower)
            await expect(
                newCacao.acceptOffer(
                    ethers.constants.AddressZero,
                    tokenId,
                    offerId,
                    { value: price }
                )
            ).to.be.revertedWithCustomError(Cacao, "Cacao__WrongAddress")
        })

        it("check if delegation was successful", async () => {
            const offerId = 0
            const newCacao = Cacao.connect(borrower)
            await newCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })
            expect(
                await Delegator.checkDelegateForToken(
                    borrower.address,
                    Cacao.address,
                    Fbayc.address,
                    tokenId
                )
            ).to.be.equal(true)
        })

        it("updates lenders balance", async () => {
            const offerId = 0
            const newCacao = Cacao.connect(borrower)
            await newCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })

            const balance = BigInt(price - (price * 3) / 100)
            expect(await Cacao.getEthBalance(deployer.address)).equal(balance)
        })

        it("taking the fee and updates the marketplace balance", async () => {
            const offerId = 0
            const newCacao = Cacao.connect(borrower)
            await newCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })

            const balance = BigInt((price * 3) / 100)
            expect(await Cacao.getEthBalance(Cacao.address)).equal(balance)
        })

        it("updates offer status to offerStatus.EXECUTED", async () => {
            const offerId = 0
            const newCacao = Cacao.connect(borrower)
            await newCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })
            expect((await Cacao.getOfferById(offerId)).status).equal(2)
        })

        it("emits OfferAccepted event", async () => {
            const offerId = 0
            const newCacao = Cacao.connect(borrower)
            const tx = newCacao.acceptOffer(Fbayc.address, tokenId, offerId, {
                value: price,
            })
            await expect(tx).to.emit(Cacao, "OfferAccepted")
        })
    })
})
