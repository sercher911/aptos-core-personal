#[test_only]
module vault::core_tests {
    use std::signer;
    use std::unit_test;
    use std::vector;
    use std::string;
    use aptos_framework::coin;
    use aptos_std::type_info;

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

        core::register_coin<WUSDT>(admin);
        core::register_coin<WETH>(admin);

        // check coin balance is created
        assert!(coin::balance<WUSDT>(user_addr) == 2, 0);
        assert!(coin::balance<WETH>(user_addr) == 4, 0);

        core::deposit<WUSDT>(addr, user, 1);
        core::deposit<WETH>(addr, user, 2);

        // check coin has been withdraw from user
        assert!(coin::balance<WUSDT>(user_addr) == 1, 0);
        assert!(coin::balance<WETH>(user_addr) == 2, 0);

        // check recorded vault balance is correct
        assert!(core::check_balance<WUSDT>(addr, user_addr) == 1, 0);
        assert!(core::check_balance<WETH>(addr, user_addr) == 2, 0);

        core::withdraw<WUSDT>(addr, user, 1);
        core::withdraw<WETH>(addr, user, 1);

        // check coin has been deposited to user
        assert!(coin::balance<WUSDT>(user_addr) == 2, 0);
        assert!(coin::balance<WETH>(user_addr) == 3, 0);

        // check recorded vault balance is correct
        assert!(core::check_balance<WUSDT>(addr, user_addr) == 0, 0);
        assert!(core::check_balance<WETH>(addr, user_addr) == 1, 0);
    }

    #[test]
    public entry fun signer_can_pause_unpause() {
        let admin = &get_account();
        let addr = signer::address_of(admin);
        aptos_framework::account::create_account_for_test(addr);

        core::init(admin);

        // check it is paused first
        assert!(core::check_pause_status(addr) == true, 0);

        core::unpause(admin);
        assert!(core::check_pause_status(addr) == false, 0);

        core::pause(admin);
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
