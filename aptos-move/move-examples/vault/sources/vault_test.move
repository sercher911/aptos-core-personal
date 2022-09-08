#[test_only]
module vault::core_tests {
    use std::signer;
    use std::unit_test;
    use std::vector;
    use std::debug;
    // use std::string;

    use vault::core;

    fun get_account(): signer {
        vector::pop_back(&mut unit_test::create_signers_for_testing(1))
    }

    fun get_user_account(): signer {
        vector::pop_back(&mut unit_test::create_signers_for_testing(2))
    }

    #[test]
    public entry fun only_signer_can_pause_unpause() {
        let admin = get_account();
        let addr = signer::address_of(&admin);
        aptos_framework::account::create_account_for_test(addr);

        core::init(admin);

        // check it is paused first
        debug::print(&core::check_pause_status(addr));
        assert!(core::check_pause_status(addr) == true, 0);

        core::unpause(addr);
        debug::print(&core::check_pause_status(addr));
        assert!(core::check_pause_status(addr) == false, 0);

        core::pause(addr);
        debug::print(&core::check_pause_status(addr));
        assert!(core::check_pause_status(addr) == true, 0);


        let user = get_user_account();
        let user_addr = signer::address_of(&user);
        aptos_framework::account::create_account_for_test(user_addr);

        debug::print(&addr);
        debug::print(&user_addr);
        // attemp to unpause, should fail
        core::unpause(user_addr);
        assert!(core::check_pause_status(user_addr) == true, 0);
    }
}
