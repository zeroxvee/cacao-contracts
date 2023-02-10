
const { assert, expect } = require("chai")
const { network, deployments, ethers, getNamedAccounts } = require("hardhat")

describe("Cacao", () => {
  let Cacao, Delegator, deployer, funder
  const sendValue = ethers.utils.parseEther("1")
  // const fundFile = JSON.parse(
  //     fs.readFileSync("./artifacts/contracts/Fund.sol/Fund.json", "utf-8")
  // )
  // const fundABI = fundFile.abi

  beforeEach(async () => {
      const accounts = await ethers.getSigners()
      deployer = accounts[0]
      lender = accounts[1]
      borrower = accounts[2]
      hacker = accounts[3]
      await deployments.fixture(["all"])
      Delegator = await ethers.getContract("DelegationRegistry", deployer)
      Cacao = await ethers.getContract("Cacao", deployer)

      console.log("all well")
  })

  describe("create offer", () => {
    const tokenId = 0
    const collection = 
    uint256 _price,
    uint256 _tokenId,
    address _collection,
    uint256 _duration
    it("creates offer", async () => {
      await Cacao.createOffer(sendValue, );
    })

    // it("initialized properly", async () => {
    //     const masterContract = await FundMeFactory.masterContract()
    //     expect(masterContract).equal(Fund.address)
    // })

    // it("should initialize fundsIndexCounter to 0", async () => {
    //     const fundsIndexCounter = await FundMeFactory.fundsIndexCounter()
    //     expect(fundsIndexCounter.toNumber()).to.equal(0)
    // })

    // it("should initialize i_minFundETH to the correct value", async () => {
    //     const i_minFundETH = await FundMeFactory.i_minFundETH()
    //     const minETH = ethers.utils.parseEther("0.1")
    //     expect(i_minFundETH.toString()).to.equal(minETH)
    // })

    // it("should initialize i_owner to the msg.sender", async () => {
    //     const i_owner = await FundMeFactory.i_owner()
    //     expect(i_owner).to.equal(deployer.address)
    // })

    // it("should initialize funds array to an empty array", async () => {
    //     const funds = await FundMeFactory.getFunds()
    //     expect(funds.length).to.equal(0)
    // })
})
})

// describe("Cacao", function () {
//   // We define a fixture to reuse the same setup in every test.
//   // We use loadFixture to run this setup once, snapshot that state,
//   // and reset Hardhat Network to that snapshot in every test.
//   async function deployOneYearLockFixture() {
//     const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
//     const ONE_GWEI = 1_000_000_000;

//     const lockedAmount = ONE_GWEI;
//     const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS;

//     // Contracts are deployed using the first signer/account by default
//     const [owner, otherAccount] = await ethers.getSigners();

//     const Lock = await ethers.getContractFactory("Lock");
//     const lock = await Lock.deploy(unlockTime, { value: lockedAmount });

//     return { lock, unlockTime, lockedAmount, owner, otherAccount };
//   }

//   describe("Deployment", function () {
//     it("Should set the right unlockTime", async function () {
//       const { lock, unlockTime } = await loadFixture(deployOneYearLockFixture);

//       expect(await lock.unlockTime()).to.equal(unlockTime);
//     });

//     it("Should set the right owner", async function () {
//       const { lock, owner } = await loadFixture(deployOneYearLockFixture);

//       expect(await lock.owner()).to.equal(owner.address);
//     });

//     it("Should receive and store the funds to lock", async function () {
//       const { lock, lockedAmount } = await loadFixture(
//         deployOneYearLockFixture
//       );

//       expect(await ethers.provider.getBalance(lock.address)).to.equal(
//         lockedAmount
//       );
//     });

//     it("Should fail if the unlockTime is not in the future", async function () {
//       // We don't use the fixture here because we want a different deployment
//       const latestTime = await time.latest();
//       const Lock = await ethers.getContractFactory("Lock");
//       await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
//         "Unlock time should be in the future"
//       );
//     });
//   });

//   describe("Withdrawals", function () {
//     describe("Validations", function () {
//       it("Should revert with the right error if called too soon", async function () {
//         const { lock } = await loadFixture(deployOneYearLockFixture);

//         await expect(lock.withdraw()).to.be.revertedWith(
//           "You can't withdraw yet"
//         );
//       });

//       it("Should revert with the right error if called from another account", async function () {
//         const { lock, unlockTime, otherAccount } = await loadFixture(
//           deployOneYearLockFixture
//         );

//         // We can increase the time in Hardhat Network
//         await time.increaseTo(unlockTime);

//         // We use lock.connect() to send a transaction from another account
//         await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
//           "You aren't the owner"
//         );
//       });

//       it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
//         const { lock, unlockTime } = await loadFixture(
//           deployOneYearLockFixture
//         );

//         // Transactions are sent using the first signer by default
//         await time.increaseTo(unlockTime);

//         await expect(lock.withdraw()).not.to.be.reverted;
//       });
//     });

//     describe("Events", function () {
//       it("Should emit an event on withdrawals", async function () {
//         const { lock, unlockTime, lockedAmount } = await loadFixture(
//           deployOneYearLockFixture
//         );

//         await time.increaseTo(unlockTime);

//         await expect(lock.withdraw())
//           .to.emit(lock, "Withdrawal")
//           .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
//       });
//     });

//     describe("Transfers", function () {
//       it("Should transfer the funds to the owner", async function () {
//         const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
//           deployOneYearLockFixture
//         );

//         await time.increaseTo(unlockTime);

//         await expect(lock.withdraw()).to.changeEtherBalances(
//           [owner, lock],
//           [lockedAmount, -lockedAmount]
//         );
//       });
//     });
//   });
// });
