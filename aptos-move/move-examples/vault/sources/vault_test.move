#[test_only]
module vault::core_tests {
    use std::signer;
    use std::unit_test;
    use std::vector;
    use std::debug;
    // use aptos_framework::aggregator_factory;
    use std::string;
    use aptos_framework::coin;
    use aptos_std::type_info;
    // use aptos_framework::genesis;

    use vault::core;
    struct WUSDT has copy, drop, store {}
    struct WETH has copy, drop, store {}


    fun get_account(): signer {
        vector::pop_back(&mut unit_test::create_signers_for_testing(1))
    }

    fun get_user_account(): signer {
        vector::pop_back(&mut unit_test::create_signers_for_testing(2))
    }

    struct Coin<phantom FakeMoney> has store {
        /// Amount of coin this address has.
        value: u64,
    }

    struct FakeMoneyCapabilities<phantom FakeMoney> has key {
        burn_cap: coin::BurnCapability<FakeMoney>,
        freeze_cap: coin::FreezeCapability<FakeMoney>,
        mint_cap: coin::MintCapability<FakeMoney>,
    }

    #[test_only]
    fun initialize_and_register_fake_money<FakeMoney>(
        account: &signer,
        decimals: u8,
        monitor_supply: bool,
    ): (coin::BurnCapability<FakeMoney>, coin::FreezeCapability<FakeMoney>, coin::MintCapability<FakeMoney>) {
        let name = string::utf8(type_info::struct_name(&type_info::type_of<FakeMoney>()));

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<FakeMoney>(
            account,
            name,
            name,
            decimals,
            monitor_supply
        );
        coin::register<FakeMoney>(account);
        (burn_cap, freeze_cap, mint_cap)
    }

    #[test_only]
    fun create_fake_money<FakeMoney>(
        source: &signer,
        destination: &signer,
        amount: u64
    ) {
        let (burn_cap, freeze_cap, mint_cap) = initialize_and_register_fake_money<FakeMoney>(source, 18, true);

        coin::register<FakeMoney>(destination);
        let coins_minted = coin::mint<FakeMoney>(amount, &mint_cap);
        coin::deposit(signer::address_of(destination), coins_minted);
        move_to(source, FakeMoneyCapabilities {
            burn_cap,
            freeze_cap,
            mint_cap,
        });
    }

    // #[test]
    // public entry fun user_cannot_deposit_unapproved_coin() {
    //     let admin = &get_account();
    //     let addr = signer::address_of(admin);
    //     aptos_framework::account::create_account_for_test(addr);

    //     core::init(admin);

    //     let user = &get_user_account();
    //     let user_addr = signer::address_of(user);
    //     aptos_framework::account::create_account_for_test(user_addr);

    //     let coin_addr = signer::address_of(&get_account());

    //     core::deposit(addr, user, coin_addr, 1);
    //     assert!(core::get_vault_coin_amount(addr, user_addr, coin_addr) == 1, 0);

    //     core::add_vault_coin(addr, user, coin_addr, 2);
    //     assert!(core::get_vault_coin_amount(addr, user_addr, coin_addr) == 3, 0);
    // }

    #[test(admin_addr=@vault)]
    public entry fun user_can_deposit(admin_addr: signer) {
        let admin = &admin_addr;
        let addr = signer::address_of(admin);
        aptos_framework::account::create_account_for_test(addr);

        core::init(admin);

        let user = &get_user_account();
        let user_addr = signer::address_of(user);
        aptos_framework::account::create_account_for_test(user_addr);

        create_fake_money<WUSDT>(admin, user, 2);
        create_fake_money<WETH>(admin, user, 4);

        // check coin balance is created
        assert!(coin::balance<WUSDT>(user_addr) == 2, 0);
        assert!(coin::balance<WETH>(user_addr) == 4, 0);

        core::deposit<WUSDT>(addr, user, 1);
        core::deposit<WETH>(addr, user, 2);

        // check coin has been withdraw
        assert!(coin::balance<WUSDT>(user_addr) == 1, 0);
        assert!(coin::balance<WETH>(user_addr) == 2, 0);

        // check coin has been deposited
        assert!(coin::balance<WUSDT>(addr) == 1, 0);
        assert!(coin::balance<WETH>(addr) == 2, 0);

        // debug::print(&core::check_balance<WUSDT>(addr, user_addr));
        debug::print(&core::coin_address<WUSDT>());
        debug::print(&core::coin_address<WETH>());
        // check deposit is recorded correctly
        assert!(core::check_balance<WUSDT>(addr, user_addr) == 1, 0);
        assert!(core::check_balance<WETH>(addr, user_addr) == 2, 0);

        // core::deposit(addr, user, coin_addr, 1);
        // assert!(core::get_vault_coin_amount(addr, user_addr, coin_addr) == 1, 0);

        // core::add_vault_coin(addr, user, coin_addr, 2);
        // assert!(core::get_vault_coin_amount(addr, user_addr, coin_addr) == 3, 0);
    }

    #[test]
    public entry fun signer_can_pause_unpause() {
        let admin = &get_account();
        let addr = signer::address_of(admin);
        aptos_framework::account::create_account_for_test(addr);

        core::init(admin);

        // check it is paused first
        debug::print(&core::check_pause_status(addr));
        assert!(core::check_pause_status(addr) == true, 0);

        core::unpause(admin);
        debug::print(&core::check_pause_status(addr));
        assert!(core::check_pause_status(addr) == false, 0);

        core::pause(admin);
        debug::print(&core::check_pause_status(addr));
        assert!(core::check_pause_status(addr) == true, 0);
    }

    #[test]
    #[expected_failure]
    public entry fun users_cannot_pause_unpause() {
        let admin = &get_account();
        let addr = signer::address_of(admin);
        aptos_framework::account::create_account_for_test(addr);

        core::init(admin);

        let user = &get_user_account();
        let user_addr = signer::address_of(user);
        aptos_framework::account::create_account_for_test(user_addr);

        // attemp to unpause, should fail
        core::unpause(user);
    }
}
