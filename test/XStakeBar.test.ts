// @ts-ignore
import { ethers, upgrades  } from "hardhat";
import { expect } from "chai";
import {ReactToken, ReactToken__factory} from "../types";

describe("XStakeBar", function () {
  before(async function () {
    this.ReactToken = (await ethers.getContractFactory(
        'ReactToken'
    )) as ReactToken__factory

    this.ReactBar = await ethers.getContractFactory("XStakeBar")

    this.signers = await ethers.getSigners()
    this.alice = this.signers[0]
    this.bob = this.signers[1]
    this.carol = this.signers[2]
  })

  beforeEach(async function () {
    this.react = (await upgrades.deployProxy(this.ReactToken, {
      kind: 'uups',
    })) as ReactToken

    await this.react.deployed()
    this.bar = await this.ReactBar.deploy(this.react.address)
    this.react.grantRole(ethers.utils.id('MINTER_ROLE'), this.alice.address)
    this.react.mint(this.alice.address, "100")
    this.react.mint(this.bob.address, "100")
    this.react.mint(this.carol.address, "100")
  })

  it("should not allow enter if not enough approve", async function () {
    await expect(this.bar.enter("100")).to.be.revertedWith("ERC20: transfer amount exceeds allowance")
    await this.react.approve(this.bar.address, "50")
    await expect(this.bar.enter("100")).to.be.revertedWith("ERC20: transfer amount exceeds allowance")
    await this.react.approve(this.bar.address, "100")
    await this.bar.enter("100")
    expect(await this.bar.balanceOf(this.alice.address)).to.equal("100")
  })

  it("should not allow withraw more than what you have", async function () {
    await this.react.approve(this.bar.address, "100")
    await this.bar.enter("100")
    await expect(this.bar.leave("200")).to.be.revertedWith("ERC20: burn amount exceeds balance")
  })

  it("should work with more than one participant", async function () {
    await this.react.approve(this.bar.address, "100")
    await this.react.connect(this.bob).approve(this.bar.address, "100", { from: this.bob.address })
    // Alice enters and gets 20 shares. Bob enters and gets 10 shares.
    await this.bar.enter("20")
    await this.bar.connect(this.bob).enter("10", { from: this.bob.address })
    expect(await this.bar.balanceOf(this.alice.address)).to.equal("20")
    expect(await this.bar.balanceOf(this.bob.address)).to.equal("10")
    expect(await this.react.balanceOf(this.bar.address)).to.equal("30")
    // ReactBar get 20 more REACTs from an external source.
    await this.react.connect(this.carol).transfer(this.bar.address, "20", { from: this.carol.address })
    // Alice deposits 10 more REACTs. She should receive 10*30/50 = 6 shares.
    await this.bar.enter("10")
    expect(await this.bar.balanceOf(this.alice.address)).to.equal("26")
    expect(await this.bar.balanceOf(this.bob.address)).to.equal("10")
    // Bob withdraws 5 shares. He should receive 5*60/36 = 8 shares
    await this.bar.connect(this.bob).leave("5", { from: this.bob.address })
    expect(await this.bar.balanceOf(this.alice.address)).to.equal("26")
    expect(await this.bar.balanceOf(this.bob.address)).to.equal("5")
    expect(await this.react.balanceOf(this.bar.address)).to.equal("52")
    expect(await this.react.balanceOf(this.alice.address)).to.equal("70")
    expect(await this.react.balanceOf(this.bob.address)).to.equal("98")
  })
})
