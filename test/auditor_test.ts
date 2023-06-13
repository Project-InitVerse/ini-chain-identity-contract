import type {AuditorFactory,Auditor,ProviderFactory} from "../types";
const {ethers}= require('hardhat')
import {expect} from "chai";
import {BigNumber} from "ethers";
import { Provider } from "../types";

describe('auditor test',function(){
  let factory_admin:any,auditor1:any,auditor2:any,provider1:any,provider2:any;
  let provider_contract_1:any,provider_contract_2:any;
  let zero_address: string = '0x0000000000000000000000000000000000000000';
  beforeEach(async function(){
    [factory_admin,auditor1,auditor2,provider1,provider2] = await ethers.getSigners()
    this.orderFactory = await (await ethers.getContractFactory('MockOrder')).deploy();
    this.AuditorFactory = await (await ethers.getContractFactory('AuditorFactory', factory_admin)).deploy(factory_admin.address);
    this.providerFactory = await (await ethers.getContractFactory('ProviderFactory',factory_admin)).deploy();
    await this.providerFactory.initialize(factory_admin.address);
    await this.providerFactory.changeAuditorFactory(this.AuditorFactory.address);
    await this.providerFactory.changeOrderFactory(this.orderFactory.address);

    await this.providerFactory.connect(provider1).createNewProvider(3,6,9,"{}",{value:ethers.utils.parseEther("1")});
    await this.providerFactory.connect(provider2).createNewProvider(9,6,3,"{}",{value:ethers.utils.parseEther("1")});
    provider_contract_1 = await this.providerFactory.providers(provider1.address);
    provider_contract_2 = await this.providerFactory.providers(provider2.address);
    this.provide_contract1 = <Provider>await ethers.getContractAt("Provider",provider_contract_1);
    this.provide_contract2 = <Provider>await ethers.getContractAt("Provider",provider_contract_2);
  })
  it("init", async function() {
    expect(await this.AuditorFactory.auditors(auditor1.address)).to.equal(zero_address)
    expect(await this.AuditorFactory.auditors(auditor2.address)).to.equal(zero_address)
  });
  it("create auditor", async function() {
    await expect(this.AuditorFactory.connect(auditor1).createAuditor("cc")).to.be.revertedWith('AuditorFactory:you must pledge money to be a auditor');
    await this.AuditorFactory.connect(auditor1).createAuditor("cc",{value:ethers.utils.parseEther("1")});
    await expect(this.AuditorFactory.connect(auditor1).createAuditor("cc")).to.be.revertedWith('AuditorFactory:only not auditor can use this function');
    expect(await this.AuditorFactory.auditors(auditor1.address)).to.not.equal(zero_address);
    expect(await this.AuditorFactory.auditors(auditor2.address)).to.equal(zero_address);
  });
  it("auditor provider init state",async function(){
    await this.AuditorFactory.connect(auditor1).createAuditor("cc",{value:ethers.utils.parseEther("1")});
    await this.AuditorFactory.connect(auditor2).createAuditor("dd",{value:ethers.utils.parseEther("1")});
    let auditor_contract1 = await this.AuditorFactory.auditors(auditor1.address);
    let auditor_contract2 = await this.AuditorFactory.auditors(auditor2.address);
    let auditor_c1 = <Auditor>await ethers.getContractAt('Auditor',auditor_contract1);
    let auditor_c2 = <Auditor>await ethers.getContractAt('Auditor',auditor_contract2);
    expect(await this.AuditorFactory.getProviderJson(auditor_contract1,provider_contract_1)).to.equal("{}")
    expect(await this.AuditorFactory.getProviderJson(auditor_contract2,provider_contract_1)).to.equal("{}")
    expect(await auditor_c1.getProviderCheckJson(provider_contract_1)).to.equal("{}")
    expect(await auditor_c2.getProviderCheckJson(provider_contract_1)).to.equal("{}")
    expect(await this.AuditorFactory.provider_auditor_state(provider_contract_1,auditor_contract1)).to.equal(0);
    expect(await this.AuditorFactory.provider_auditor_state(provider_contract_1,auditor_contract2)).to.equal(0);
    let c = await this.AuditorFactory.getProviderAuditors(provider_contract_1)
    expect(c.length).to.equal(0);
    c = await this.AuditorFactory.getProviderAuditors(provider_contract_2)
    expect(c.length).to.equal(0);
  })
  it("auditor set provider state", async function() {
    await this.AuditorFactory.connect(auditor1).createAuditor("cc",{value:ethers.utils.parseEther("1")});
    let auditor_contract1 = await this.AuditorFactory.auditors(auditor1.address);
    let auditor_c1 = <Auditor>await ethers.getContractAt('Auditor',auditor_contract1);
    await expect(auditor_c1.uploadProviderState(provider_contract_1,"{}")).to.be.revertedWith('Auditor:only admin can use this function');
    await auditor_c1.connect(auditor1).uploadProviderState(provider_contract_1,"{}");
    expect(await this.AuditorFactory.provider_auditor_state(provider_contract_1,auditor_contract1)).to.equal(2);
    let c = await this.AuditorFactory.getProviderAuditors(provider_contract_1)
    expect(c.length).to.equal(0);
    await auditor_c1.connect(auditor1).uploadProviderState(provider_contract_1,"{\"key\":cc}");
    expect(await this.AuditorFactory.provider_auditor_state(provider_contract_1,auditor_contract1)).to.equal(1);
    c = await this.AuditorFactory.getProviderAuditors(provider_contract_1)
    expect(c.length).to.equal(1);
    expect(c[0]).to.equal(auditor_contract1);
    expect(await this.AuditorFactory.getProviderJson(auditor_contract1,provider_contract_1)).to.equal("{\"key\":cc}")
  });
  it("provider info from auditor", async function() {
    await this.AuditorFactory.connect(auditor1).createAuditor("cc",{value:ethers.utils.parseEther("1")});
    await this.AuditorFactory.connect(auditor2).createAuditor("dd",{value:ethers.utils.parseEther("1")});
    let auditor_contract1 = await this.AuditorFactory.auditors(auditor1.address);
    let auditor_contract2 = await this.AuditorFactory.auditors(auditor2.address);
    let auditor_c1 = <Auditor>await ethers.getContractAt('Auditor',auditor_contract1);
    let auditor_c2 = <Auditor>await ethers.getContractAt('Auditor',auditor_contract2);
    await auditor_c1.connect(auditor1).uploadProviderState(provider_contract_1,"{\"key\":cc}");
    await auditor_c2.connect(auditor2).uploadProviderState(provider_contract_1,"{\"key\":cc}");
    await expect(this.providerFactory.getProviderInfo(1,0)).to.be.revertedWith("must start with zero");
    await expect(this.providerFactory.getProviderInfo(3,1)).to.be.revertedWith("start>provider_array.length");
    let c =await this.providerFactory.getProviderInfo(1,1);
    expect(c.length).to.equal(1)
    c = await this.providerFactory.getProviderInfo(0,0);
    expect(c.length).to.equal(2)
    console.log(c)
    expect(c[0]['audits'][0]).to.equal(auditor_contract1);
    expect(c[0]['audits'][1]).to.equal(auditor_contract2);
  });
})
