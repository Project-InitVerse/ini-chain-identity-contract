import { BigNumber } from "ethers";

const {ethers,network} = require('hardhat')
import chai, { expect } from "chai";
import type {MockOrder,AuditorFactory,ProviderFactory,Provider,PunishContract,MockOwner} from "../types";

describe('provider test',function(){
  let factory_admin:any,provider_1:any,provider_2:any,cus:any;
  let zero_addr: string = '0x0000000000000000000000000000000000000000'
  beforeEach(async function(){
    [factory_admin,provider_1,provider_2,cus] = await ethers.getSigners();
    this.orderFactory = await (await ethers.getContractFactory('MockOrder')).deploy();
    this.adminFactory = await (await ethers.getContractFactory('AuditorFactory', factory_admin)).deploy(factory_admin.address);
    this.providerFactory = await (await ethers.getContractFactory('ProviderFactory',factory_admin)).deploy();
    this.punishItem = await (await ethers.getContractFactory('PunishContract',factory_admin)).deploy();
    this.MockOwner = await (await ethers.getContractFactory('MockOwner')).deploy();
    await this.punishItem.setFactoryAddr(this.providerFactory.address);
    await this.providerFactory.initialize(factory_admin.address);
    await this.providerFactory.changeAuditorFactory(this.adminFactory.address);
    await this.providerFactory.changeOrderFactory(this.orderFactory.address);
    await this.providerFactory.changeProviderPunishItemAddr(this.punishItem.address);
    await this.MockOwner.setfactory(this.providerFactory.address,zero_addr);


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
    expect(await this.punishItem.current_index()).to.equal(1);
    expect(await this.punishItem.getProviderPunishLength(provider_1.address)).to.equal(1);
    let punishInfo = await this.punishItem.index_punish_items(0)
    expect(punishInfo.punish_owner).to.equal(provider_1.address)
    expect(punishInfo.punish_amount).to.equal(ethers.utils.parseEther('1'))
    expect(punishInfo.balance_left).to.equal(punish_balance)
  })
  it("Provider punish all",async function () {
    await this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"cn","{}",{value:ethers.utils.parseEther("1")});
    await this.providerFactory.connect(provider_2).createNewProvider(9,6,3,"cn","{}",{value:ethers.utils.parseEther("1")});
    await this.providerFactory.connect(factory_admin).changeDecimal(1,1);
    await this.providerFactory.connect(factory_admin).changePunishPercent(1,1)
    let provider_c1 = await this.providerFactory.providers(provider_1.address);
    let provider_c2 = await this.providerFactory.providers(provider_2.address);
    let p1_punish_start_balance = await ethers.provider.getBalance(provider_c1);
    let p2_punish_start_balance = await ethers.provider.getBalance(provider_c2);
    expect(p1_punish_start_balance).to.equal(ethers.utils.parseEther("1"));
    expect(p2_punish_start_balance).to.equal(ethers.utils.parseEther("1"));
    await this.providerFactory.tryPunish(provider_1.address)
    expect(await this.providerFactory.getPunishLength()).to.equal(1)

    let punishBlock = await ethers.provider.getBlock("latest");
    let provider1_contract = await ethers.getContractAt('Provider',provider_c1)
    let provider2_contract = await ethers.getContractAt('Provider',provider_c2)
    expect(await provider1_contract.punish_start_time()).to.equal(punishBlock.timestamp);
    expect(await provider1_contract.state()).to.equal(1);
    expect(await provider1_contract.punish_start_margin_amount()).to.equal(ethers.utils.parseEther("1"));
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [punishBlock.timestamp+48*3600+30],
    });
    await this.providerFactory.tryPunish(provider_1.address)
    expect(await this.providerFactory.getPunishLength()).to.equal(0)
    let punish_balance = await ethers.provider.getBalance(provider_c1);
    expect(p1_punish_start_balance.sub(punish_balance)).to.equal(p1_punish_start_balance);
    expect(await this.punishItem.current_index()).to.equal(1);
    expect(await this.punishItem.getProviderPunishLength(provider_1.address)).to.equal(1);
    let punishInfo = await this.punishItem.index_punish_items(0)
    expect(punishInfo.punish_owner).to.equal(provider_1.address)
    expect(punishInfo.punish_amount).to.equal(p1_punish_start_balance)
    expect(punishInfo.balance_left).to.equal(punish_balance)
    expect(punishInfo.balance_left).to.equal(0)
    expect(await provider1_contract.state()).to.equal(2);
    await this.providerFactory.connect(provider_1).addMargin({value:ethers.utils.parseEther("3000")})
    expect(await provider1_contract.state()).to.equal(0);
    expect(await this.providerFactory.getPunishLength()).to.equal(0)
    await this.providerFactory.tryPunish(provider_1.address)
    await this.providerFactory.tryPunish(provider_2.address)
    let count = 0;
    let punishAddrs = await this.providerFactory.getPunishAddress();
    for(let i=0;i < punishAddrs.length;i++){
      if(punishAddrs[i] == provider_1.address || punishAddrs[i] == provider_2.address){
        count = count+1;
      }
    }
    expect(count).to.equal(2);
    punishBlock = await ethers.provider.getBlock("latest");
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [punishBlock.timestamp+48*3600+30],
    });
    await this.providerFactory.tryPunish(zero_addr);
    expect(await this.providerFactory.getPunishLength()).to.equal(0)
    expect(await provider1_contract.state()).to.equal(2);
    expect(await provider2_contract.state()).to.equal(2);
    punishInfo = await this.punishItem.index_punish_items(0)
    expect(punishInfo.punish_owner).to.equal(provider_1.address)
    expect(punishInfo.punish_amount).to.equal(p1_punish_start_balance)
    expect(punishInfo.balance_left).to.equal(punish_balance)
    expect(punishInfo.balance_left).to.equal(0)
    punishInfo = await this.punishItem.index_punish_items(1)
    expect(punishInfo.punish_owner).to.equal(provider_1.address)
    expect(punishInfo.punish_amount).to.equal(ethers.utils.parseEther("3000"))
    expect(punishInfo.balance_left).to.equal(0)
    punishInfo = await this.punishItem.index_punish_items(2)
    expect(punishInfo.punish_owner).to.equal(provider_2.address)
    expect(punishInfo.punish_amount).to.equal(ethers.utils.parseEther("1"))
    expect(punishInfo.balance_left).to.equal(0)
  })
  it("mock owner",async function(){
    await this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"cn","{}",{value:ethers.utils.parseEther("1")});
    let provider_c1 = await this.providerFactory.providers(provider_1.address);
    let provider1_contract = await ethers.getContractAt('Provider',provider_c1);
    let total_all = await this.providerFactory.total_all();
    let total_used = await this.providerFactory.total_used();
    expect(total_all.cpu_count).to.equal(3);
    expect(total_all.memory_count).to.equal(6);
    expect(total_all.storage_count).to.equal(9);
    expect(total_used.cpu_count).to.equal(0);
    expect(total_used.memory_count).to.equal(0);
    expect(total_used.storage_count).to.equal(0);
    await this.MockOwner.setOwner(provider_1.address);
    await expect(this.MockOwner.mockAttack(true,zero_addr)).to.be.revertedWith("provider contract equal");
    await provider1_contract.connect(provider_1).updateResource(5,5,5);
    total_all = await this.providerFactory.total_all();
    total_used = await this.providerFactory.total_used();
    expect(total_all.cpu_count).to.equal(5);
    expect(total_all.memory_count).to.equal(5);
    expect(total_all.storage_count).to.equal(5);
    expect(total_used.cpu_count).to.equal(0);
    expect(total_used.memory_count).to.equal(0);
    expect(total_used.storage_count).to.equal(0);
  })
  it("add margin", async function() {
    await this.providerFactory.connect(provider_1).createNewProvider(2000,8 * 1024 * 1024 * 1024,16 * 1024 * 1024 * 1024,"cn","{}",{value:ethers.utils.parseEther("2000")});
    let provider = await this.providerFactory.providers(provider_1.address);
    let provider_contract = await ethers.getContractAt('Provider',provider);

    let marginSize = await provider_contract.margin_size();
    expect(marginSize).to.equal(1);
    let remainMarginAmount0 = await provider_contract.connect(provider_1).getRemainMarginAmount(0);
    expect(remainMarginAmount0).to.equal(ethers.utils.parseEther('2000'));

    let punish_start_balance = await ethers.provider.getBalance(provider);
    expect(punish_start_balance).to.equal(ethers.utils.parseEther("2000"));

    // start punish
    await this.providerFactory.tryPunish(provider_1.address)
    let punishBlock = await ethers.provider.getBlock("latest");
    expect(await provider_contract.punish_start_margin_amount()).to.equal(ethers.utils.parseEther("2000"));
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [punishBlock.timestamp+48*3600+30],
    });

    // first deduct margin
    await this.providerFactory.tryPunish(provider_1.address);
    let punish_balance = await ethers.provider.getBalance(provider);
    // punish amount
    expect(punish_start_balance.sub(punish_balance)).to.equal(ethers.utils.parseEther('20'));

    // margin0 remain amount
    remainMarginAmount0 = await provider_contract.connect(provider_1).getRemainMarginAmount(0);
    expect(remainMarginAmount0).to.equal(ethers.utils.parseEther('1980'));

    punishBlock = await ethers.provider.getBlock("latest");
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [punishBlock.timestamp+24*3600+30],
    });
    // add margin, total: 1980 + 2020 = 4000
    await this.providerFactory.connect(provider_1).addMargin({value:ethers.utils.parseEther("2020")});
    let remainMarginAmount1 = await provider_contract.connect(provider_1).getRemainMarginAmount(1);
    expect(remainMarginAmount1).to.equal(ethers.utils.parseEther('2020'));
    marginSize = await provider_contract.margin_size();
    expect(marginSize).to.equal(2);

    // second deduct margin
    await this.providerFactory.tryPunish(provider_1.address);
    punish_balance = await ethers.provider.getBalance(provider);
    // punish balance, 4000 - 20 = 3980
    expect(punish_balance).to.equal(ethers.utils.parseEther('3980'));

    // margin0 remain amount, 1980 - 20 * 1980 / 4000 = 1980 - 9.9 = 1970.1
    remainMarginAmount0 = await provider_contract.connect(provider_1).getRemainMarginAmount(0);
    expect(remainMarginAmount0).to.equal(ethers.utils.parseEther('1970.1'));

    // margin1 remain amount, 2020 - 20 * 2020 / 4000 = 2020 - 10.1 = 2009.9
    remainMarginAmount1 = await provider_contract.connect(provider_1).getRemainMarginAmount(1);
    expect(remainMarginAmount1).to.equal(ethers.utils.parseEther('2009.9'));

    punishBlock = await ethers.provider.getBlock("latest");
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [punishBlock.timestamp+24*3600+30],
    });

    // add margin, total: 3980 + 1020 = 5000
    await this.providerFactory.connect(provider_1).addMargin({value:ethers.utils.parseEther("1020")});
    let remainMarginAmount2 = await provider_contract.connect(provider_1).getRemainMarginAmount(2);
    expect(remainMarginAmount2).to.equal(ethers.utils.parseEther('1020'));
    marginSize = await provider_contract.margin_size();
    expect(marginSize).to.equal(3);

    // third deduct margin
    await this.providerFactory.tryPunish(provider_1.address);
    punish_balance = await ethers.provider.getBalance(provider);
    // punish balance, 5000 - 20 = 4980
    expect(punish_balance).to.equal(ethers.utils.parseEther('4980'));

    // margin0 remain amount, 1970.1 - 20 * 1970.1 / 5000 = 1970.1 - 7.8804 = 1962.2196
    remainMarginAmount0 = await provider_contract.connect(provider_1).getRemainMarginAmount(0);
    expect(remainMarginAmount0).to.equal(ethers.utils.parseEther('1962.2196'));

    // margin1 remain amount, 2009.9 - 20 * 2009.9 / 5000 = 2009.9 - 8.0396 = 2001.8604
    remainMarginAmount1 = await provider_contract.connect(provider_1).getRemainMarginAmount(1);
    expect(remainMarginAmount1).to.equal(ethers.utils.parseEther('2001.8604'));

    // margin2 remain amount, 1020 - 20 * 1020 / 5000 = 1000 - 4.08 = 1015.92
    remainMarginAmount2 = await provider_contract.connect(provider_1).getRemainMarginAmount(2);
    expect(remainMarginAmount2).to.equal(ethers.utils.parseEther('1015.92'));
  });
})
