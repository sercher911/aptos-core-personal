module vault::core {
    use std::error;
    // use std::vector;
    use std::signer;
    // use std::string;
    // use aptos_framework::account;
    use aptos_std::table;
    // use aptos_framework::coin::{Self, Coin};
    // friend aptos_framework::aptos_coin;
    // friend aptos_framework::genesis;

// //:!:>resource
//     struct MessageHolder has key {
//         message: string::String,
//         message_change_events: event::EventHandle<MessageChangeEvent>,
//     }
// //<:!:resource
    
//     struct MessageChangeEvent has drop, store {
//         from_message: string::String,
//         to_message: string::String,
//     }

// drop, store, copy, key
    struct PauseCap has key {
        
    }

    struct PauseOrNot has key {
        paused: bool
    }

    // coinType address stored here with amount recorded
    struct Shares has store {
        coins: table::Table<address, u64>
    }

    struct VaultMap has key {
        shares: table::Table<address, Shares>
    }

    const NO_CAP: u64 = 0;
    const NOT_INITIALIZED: u64 = 1;
    const EINSUFFICIENT_BALANCE: u64 = 2;

    // pause
    // unpause
    // initialize vault creation sys with admin only rights
    // allow users to deposit a token, track user address and token value
    // allows users to withdraw a token, track user address bal

    public entry fun pause(account: &signer) acquires PauseOrNot {
        let addr = signer::address_of(account);
        assert!(exists<PauseCap>(addr), error::not_found(NO_CAP));
        borrow_global_mut<PauseOrNot>(addr).paused = true
    }

    public entry fun unpause(account: &signer) acquires PauseOrNot {
        let addr = signer::address_of(account);
        assert!(exists<PauseCap>(addr), error::not_found(NO_CAP));
        borrow_global_mut<PauseOrNot>(addr).paused = false
    }
    
    public entry fun check_pause_status(addr: address): bool acquires PauseOrNot {
        *&borrow_global<PauseOrNot>(addr).paused
    }

    public entry fun init(account: &signer) {
        // let shareMap = table::new<address, Shares>();
        
        // let (resource_signer, resource_signer_cap) = account::create_resource_account(&account, seed);

        move_to(account, PauseCap{});
        move_to(account, PauseOrNot {
            paused: true
        })

        // move_to(&account, VaultMap {
        //     shares: shareMap
        // });
    }

    // public fun get_vault_map<T>(addr: address, coin: Coin<T>) {
    //     *&borrow_global<VaultMap>(addr).paused
    // }

    // public fun deposit<T>(from: &signer, coin: Coin<T>) {
    //     let coin = coin::withdraw(from, amount);
    //     coin::deposit(to, coin);
    // }

    // public fun withdraw<T>(to: &signer, amount: u64) {
    //     let coin = coin::withdraw(from, amount);
    //     coin::deposit(to, coin);
    // }

    // public entry fun set_message(account: signer, message: string::String)
    // acquires MessageHolder {
    //     let account_addr = signer::address_of(&account);
    //     if (!exists<MessageHolder>(account_addr)) {
    //         move_to(&account, MessageHolder {
    //             message,
    //             message_change_events: account::new_event_handle<MessageChangeEvent>(&account),
    //         })
    //     } else {
    //         let old_message_holder = borrow_global_mut<MessageHolder>(account_addr);
    //         let from_message = *&old_message_holder.message;
    //         event::emit_event(&mut old_message_holder.message_change_events, MessageChangeEvent {
    //             from_message,
    //             to_message: copy message,
    //         });
    //         old_message_holder.message = message;
    //     }
    // }

    // #[test(account = @0x1)]
    // public entry fun sender_can_set_message(account: signer) acquires MessageHolder {
    //     let addr = signer::address_of(&account);
    //     aptos_framework::account::create_account_for_test(addr);
    //     set_message(account,  string::utf8(b"Hello, Blockchain"));

    //     assert!(
    //       get_message(addr) == string::utf8(b"Hello, Blockchain"),
    //       ENO_MESSAGE
    //     );
    // }
}
