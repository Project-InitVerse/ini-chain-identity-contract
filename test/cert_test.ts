import type {Cert} from "../types";
const {ethers,network}= require('hardhat')
import {expect} from "chai";
import {BigNumber} from "ethers";

describe('cert test',function(){
  let user1:any,user2:any;
  let zero_addr: string = '0x0000000000000000000000000000000000000000'
  beforeEach(async function(){
    [user1,user2] = await ethers.getSigners()
    this.Cert = await (await ethers.getContractFactory('Cert')).deploy();
  })
  it("all test", async function() {
    await this.Cert.connect(user1).createNewCert("haha1",30,1)
    let x =await this.Cert.connect(user1).getAllUserCert(user1.address)
    expect(x[0]["cert"]).to.equal("haha1")
    expect(x[0]["state"]).to.equal(1)
    await this.Cert.connect(user1).changeCertState("haha1",0)
    x =await this.Cert.connect(user1).getAllUserCert(user1.address)
    expect(x[0]["cert"]).to.equal("haha1")
    expect(x[0]["state"]).to.equal(0)
    await this.Cert.connect(user1).createNewCert("haha2",30,0)
    await this.Cert.connect(user1).createNewCert("haha3",30,0)
    let c = await this.Cert.getAllUserCert(user1.address)
    expect(c.length).to.equal(3)
    expect(c[0]["cert"]).to.equal('haha1')
    expect(c[1]["cert"]).to.equal('haha2')
    expect(c[2]["cert"]).to.equal('haha3')
    await this.Cert.connect(user1).changeCertState("haha1",1)
    await this.Cert.connect(user1).changeCertState("haha2",0)
    await this.Cert.connect(user1).changeCertState("haha3",1)
    c =await this.Cert.getAllUserCert(user1.address)
    expect(c[0]["state"]).to.equal(1)
    expect(c[1]["state"]).to.equal(0)
    expect(c[2]["state"]).to.equal(1)
  });
})
