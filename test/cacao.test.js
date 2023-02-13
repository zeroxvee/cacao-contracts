const { assert, expect } = require("chai")
const { network, deployments, ethers, getNamedAccounts } = require("hardhat")

describe("Cacao", () => {
    let Cacao, Fbayc, Delegator
    let deployer, lender, borrower
    let tokenId, price, duration, collection

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
    })

    describe("createOffer", () => {
        beforeEach(async () => {
            await Fbayc.safeMint(deployer.address)
            await Fbayc.setApprovalForAll(Cacao.address, true)
            collection = Fbayc.address
            tokenId = 0
            price = ethers.utils.parseEther("1")
            duration = 86400
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

        it("emits OfferCreated event", async () => {
            const tx = Cacao.createOffer(price, tokenId, collection, duration)
            await expect(tx).to.emit(Cacao, "OfferCreated")
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

        it("adds new offer to offerByLender mapping", async () => {
            expect(
                (await Cacao.getOfferByLender(deployer.address)).length
            ).to.be.equal(0)
            await Cacao.createOffer(price, tokenId, collection, duration)
            expect(
                (await Cacao.getOfferByLender(deployer.address)).length
            ).to.be.equal(1)
        })

        it("offer counter increment", async () => {
            expect(await Cacao.offerCounter()).to.be.equal(0)
            await Cacao.createOffer(price, tokenId, collection, duration)
            expect(await Cacao.offerCounter()).to.be.equal(1)
        })
    })
})
