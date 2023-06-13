import { BigNumber } from "ethers";

const {ethers,network} = require('hardhat')
import chai, { expect } from "chai";
import type {MockOrder,AuditorFactory,ProviderFactory,Provider} from "../types";

describe('provider test',function(){
  let factory_admin:any,provider_1:any,provider_2:any,cus:any;
  let zero_addr: string = '0x0000000000000000000000000000000000000000'
  beforeEach(async function(){
    [factory_admin,provider_1,provider_2,cus] = await ethers.getSigners();
    this.orderFactory = await (await ethers.getContractFactory('MockOrder')).deploy();
    this.adminFactory = await (await ethers.getContractFactory('AuditorFactory', factory_admin)).deploy(factory_admin.address);
    this.providerFactory = await (await ethers.getContractFactory('ProviderFactory',factory_admin)).deploy();
    await this.providerFactory.initialize(factory_admin.address);
    await this.providerFactory.changeAuditorFactory(this.adminFactory.address);
    await this.providerFactory.changeOrderFactory(this.orderFactory.address);
  })
  it('init',async function(){
    expect(await this.providerFactory.providers(provider_1.address)).to.equal(zero_addr);
    expect(await this.providerFactory.providers(provider_2.address)).to.equal(zero_addr);
    let total_all = await this.providerFactory.total_all();
    let total_used = await this.providerFactory.total_used();
    expect(total_all.cpu_count).to.equal(0);
    expect(total_all.memory_count).to.equal(0);
    expect(total_all.storage_count).to.equal(0);
    expect(total_used.cpu_count).to.equal(0);
    expect(total_used.memory_count).to.equal(0);
    expect(total_used.storage_count).to.equal(0);
    //await expect( this.providerFactory.getProvideTotalResource(provider_1.address)).to.be.revertedWith('ProviderFactory : this provider doesnt exist')
    //await expect( this.providerFactory.getProvideResource(provider_1.address)).to.be.revertedWith('ProviderFactory : this provider doesnt exist')
  })
  it("create provider", async function() {
    //await expect(this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"cn","{}")).to.be.revertedWith('ProviderFactory: you must pledge money to be a provider');
    await this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"cn","{}",{value:ethers.utils.parseEther("1")});
    await expect(this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"cn","{}")).to.be.revertedWith('only not provider');
    let provider_contract1 = await this.providerFactory.providers(provider_1.address);
    let total_all = await this.providerFactory.total_all();
    let total_used = await this.providerFactory.total_used();
    expect(total_all.cpu_count).to.equal(3);
    expect(total_all.memory_count).to.equal(6);
    expect(total_all.storage_count).to.equal(9);
    expect(total_used.cpu_count).to.equal(0);
    expect(total_used.memory_count).to.equal(0);
    expect(total_used.storage_count).to.equal(0);
    expect(await this.providerFactory.providers(provider_2.address)).to.equal(zero_addr);
    await this.providerFactory.connect(provider_2).createNewProvider(9,6,3,"cn","{}",{value:ethers.utils.parseEther("1")});
    expect(await this.providerFactory.providers(provider_2.address)).to.not.equal(zero_addr);
    let provider_contract2 = await this.providerFactory.providers(provider_2.address);
    total_all = await this.providerFactory.total_all();
    total_used = await this.providerFactory.total_used();
    expect(total_all.cpu_count).to.equal(12);
    expect(total_all.memory_count).to.equal(12);
    expect(total_all.storage_count).to.equal(12);
    expect(total_used.cpu_count).to.equal(0);
    expect(total_used.memory_count).to.equal(0);
    expect(total_used.storage_count).to.equal(0);
  });
  it("consume resource", async function() {

    await this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"cn","{}",{value:ethers.utils.parseEther("1")});
    await this.providerFactory.connect(provider_2).createNewProvider(9,6,3,"cn","{}",{value:ethers.utils.parseEther("1")});
    let provider_contract_1 = await this.providerFactory.providers(provider_1.address);
    let provider_contract_2 = await this.providerFactory.providers(provider_2.address);
    await expect(this.providerFactory.connect(cus).consumeResource(provider_contract_1,2,1,1)).to.be.revertedWith('not order user');
    await this.orderFactory.connect(cus).set()
    expect(await this.orderFactory.cc(cus.address)).to.equal(1)
    await this.providerFactory.connect(cus).consumeResource(provider_contract_1,2,1,1);
    let total_all = await this.providerFactory.total_all();
    let total_used = await this.providerFactory.total_used();
    expect(total_all.cpu_count).to.equal(12);
    expect(total_all.memory_count).to.equal(12);
    expect(total_all.storage_count).to.equal(12);
    expect(total_used.cpu_count).to.equal(2);
    expect(total_used.memory_count).to.equal(1);
    expect(total_used.storage_count).to.equal(1);
    let [x,y,z] = await this.providerFactory.getProvideResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(1));
    expect(y).to.equal(BigNumber.from(5));
    expect(z).to.equal(BigNumber.from(8));
    [x,y,z] = await this.providerFactory.getProvideTotalResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(3));
    expect(y).to.equal(BigNumber.from(6));
    expect(z).to.equal(BigNumber.from(9));
    await expect(this.providerFactory.connect(cus).consumeResource(provider_contract_1,5,1,1)).to.be.revertedWith('resource left not enough');
    await expect(this.providerFactory.connect(cus).consumeResource(provider_contract_1,1,6,1)).to.be.revertedWith('resource left not enough');
    await expect(this.providerFactory.connect(cus).consumeResource(provider_contract_1,1,1,10)).to.be.revertedWith('resource left not enough');
  });
  it("recover Resource", async function() {
    await this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"cn","{}",{value:ethers.utils.parseEther("1")});
    await this.providerFactory.connect(provider_2).createNewProvider(9,6,3,"cn","{}",{value:ethers.utils.parseEther("1")});
    let provider_contract_1 = await this.providerFactory.providers(provider_1.address);
    let provider_contract_2 = await this.providerFactory.providers(provider_2.address);
    await this.orderFactory.connect(cus).set()
    await this.providerFactory.connect(cus).consumeResource(provider_contract_1,2,1,1);
    await expect(this.providerFactory.connect(factory_admin).recoverResource(provider_contract_1,2,1,1)).to.be.revertedWith('not order user');
    await this.providerFactory.connect(cus).recoverResource(provider_contract_1,2,1,1);
    let total_all = await this.providerFactory.total_all();
    let total_used = await this.providerFactory.total_used();
    expect(total_all.cpu_count).to.equal(12);
    expect(total_all.memory_count).to.equal(12);
    expect(total_all.storage_count).to.equal(12);
    expect(total_used.cpu_count).to.equal(0);
    expect(total_used.memory_count).to.equal(0);
    expect(total_used.storage_count).to.equal(0);
    let [x,y,z] = await this.providerFactory.getProvideResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(3));
    expect(y).to.equal(BigNumber.from(6));
    expect(z).to.equal(BigNumber.from(9));
    [x,y,z] = await this.providerFactory.getProvideTotalResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(3));
    expect(y).to.equal(BigNumber.from(6));
    expect(z).to.equal(BigNumber.from(9));
    await this.providerFactory.connect(cus).consumeResource(provider_contract_1,2,1,1);
    await this.providerFactory.connect(cus).recoverResource(provider_contract_1,3,1,1);
    [x,y,z] = await this.providerFactory.getProvideResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(0));
    expect(y).to.equal(BigNumber.from(0));
    expect(z).to.equal(BigNumber.from(0));
    [x,y,z] = await this.providerFactory.getProvideTotalResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(2));
    expect(y).to.equal(BigNumber.from(1));
    expect(z).to.equal(BigNumber.from(1));
     total_all = await this.providerFactory.total_all();
     total_used = await this.providerFactory.total_used();
    expect(total_all.cpu_count).to.equal(11);
    expect(total_all.memory_count).to.equal(7);
    expect(total_all.storage_count).to.equal(4);
    expect(total_used.cpu_count).to.equal(2);
    expect(total_used.memory_count).to.equal(1);
    expect(total_used.storage_count).to.equal(1);

  });
  it("Provider Length", async function() {
    expect(await  this.providerFactory.getProviderInfoLength()).to.equal(0)
    await this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"cn","{}",{value:ethers.utils.parseEther("1")});
    expect(await  this.providerFactory.getProviderInfoLength()).to.equal(1)
    await this.providerFactory.connect(provider_2).createNewProvider(9,6,3,"cn","{}",{value:ethers.utils.parseEther("1")});
    expect(await  this.providerFactory.getProviderInfoLength()).to.equal(2)
  });
  it("Provider update",async function (){
    await this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"cn","{}",{value:ethers.utils.parseEther("1")});
    await this.providerFactory.connect(provider_2).createNewProvider(9,6,3,"cn","{}",{value:ethers.utils.parseEther("1")});

    let provider_contract_1 = await this.providerFactory.providers(provider_1.address);
    await this.orderFactory.connect(cus).set()
    await this.providerFactory.connect(cus).consumeResource(provider_contract_1,2,1,1);
    let provider_c = <Provider>await ethers.getContractAt("Provider",provider_contract_1);
    await expect(provider_c.connect(factory_admin).updateResource(0,1,1)).to.be.revertedWith('owner only');
    await provider_c.connect(provider_1).updateResource(0,1,1);
    let total_all = await this.providerFactory.total_all();
    let total_used = await this.providerFactory.total_used();
    expect(total_all.cpu_count).to.equal(11);
    expect(total_all.memory_count).to.equal(8);
    expect(total_all.storage_count).to.equal(5);
    expect(total_used.cpu_count).to.equal(2);
    expect(total_used.memory_count).to.equal(1);
    expect(total_used.storage_count).to.equal(1);
    let [x,y,z] = await this.providerFactory.getProvideResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(0));
    expect(y).to.equal(BigNumber.from(1));
    expect(z).to.equal(BigNumber.from(1));
    [x,y,z] = await this.providerFactory.getProvideTotalResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(2));
    expect(y).to.equal(BigNumber.from(2));
    expect(z).to.equal(BigNumber.from(2));
  })
  it("Provider punish",async function () {
    await this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"cn","{}",{value:ethers.utils.parseEther("1")});
    await this.providerFactory.connect(provider_2).createNewProvider(9,6,3,"cn","{}",{value:ethers.utils.parseEther("1")});
    await this.providerFactory.connect(factory_admin).changeDecimal(1,1);
    let provider_c1 = await this.providerFactory.providers(provider_1.address);
    let provider_c2 = await this.providerFactory.providers(provider_2.address);
    let p1_punish_start_balance = await ethers.provider.getBalance(provider_c1);
    let p2_punish_start_balance = await ethers.provider.getBalance(provider_c2);
    expect(p1_punish_start_balance).to.equal(ethers.utils.parseEther("1"));
    expect(p2_punish_start_balance).to.equal(ethers.utils.parseEther("1"));
    await this.providerFactory.tryPunish(provider_1.address)
    let punishBlock = await ethers.provider.getBlock("latest");
    let provider1_contract = await ethers.getContractAt('Provider',provider_c1)
    expect(await provider1_contract.punish_start_time()).to.equal(punishBlock.timestamp);
    expect(await provider1_contract.state()).to.equal(1);
    expect(await provider1_contract.punish_start_margin_amount()).to.equal(ethers.utils.parseEther("1"));
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [punishBlock.timestamp+48*3600+30],
    });
    await this.providerFactory.tryPunish(provider_1.address)
    let punish_balance = await ethers.provider.getBalance(provider_c1);
    expect(p1_punish_start_balance.sub(punish_balance)).to.equal(ethers.utils.parseEther('1'));
    /*
    await this.valFactory.initialize(whiteList,admin.address);
    await this.valFactory.connect(admin).changePunishAddress(punish_address.address);
    await this.valFactory.connect(admin).changeValidatorMinPledgeAmount(ethers.utils.parseEther("1"));
    await this.valFactory.connect(validator1).createValidator({value:ethers.utils.parseEther("1")});
    await this.valFactory.connect(admin).changeValidatorState(validator1.address,3);
    await this.valFactory.tryPunish(validator1.address);
    let punishBlock = await ethers.provider.getBlock("latest");


    let validator1_contract = await ethers.getContractAt('Validator',await this.valFactory.owner_validator(validator1.address))
    expect(await validator1_contract.punish_start_time()).to.equal(punishBlock.timestamp);
    expect(await validator1_contract.state()).to.equal(1);
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [punishBlock.timestamp+48*3600+30],
    });
    await this.valFactory.tryPunish(zeroAddress);
    expect(await validator1_contract.state()).to.equal(2);
    let punish_balance = await ethers.provider.getBalance(punish_address.address);
    expect(punish_balance.sub(punish_start_balance)).to.equal(ethers.utils.parseEther('0.01'));
    await this.valFactory.tryPunish(zeroAddress);
    expect(await validator1_contract.state()).to.equal(2);
    punish_balance = await ethers.provider.getBalance(punish_address.address);
    expect(punish_balance.sub(punish_start_balance)).to.equal(ethers.utils.parseEther('0.01'));
    expect(await validator1_contract.pledge_amount()).to.equal(ethers.utils.parseEther("0.99"))
    let block_last = await ethers.provider.getBlock("latest");
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [block_last.timestamp+1*3600+50],
    });
    await this.valFactory.tryPunish(zeroAddress);
    expect(await validator1_contract.state()).to.equal(2);
    punish_balance = await ethers.provider.getBalance(punish_address.address);
    expect(punish_balance.sub(punish_start_balance)).to.equal(ethers.utils.parseEther('0.02'));
    expect(await validator1_contract.pledge_amount()).to.equal(ethers.utils.parseEther("0.98"))
    await expect(this.valFactory.connect(validator2).MarginCalls({value:ethers.utils.parseEther("1")})).to.be.revertedWith('ValidatorFactory : you account is not a validator');
    await expect(this.valFactory.connect(validator1).MarginCalls({value:ethers.utils.parseEther("1")})).to.be.revertedWith('posMargin must less than max validator pledge amount')
    await this.valFactory.connect(validator1).MarginCalls({value:ethers.utils.parseEther("0.01")});
    expect(await validator1_contract.pledge_amount()).to.equal(ethers.utils.parseEther("0.99"))*/
  })
})
