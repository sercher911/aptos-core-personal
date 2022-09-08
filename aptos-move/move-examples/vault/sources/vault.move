module vault::core {
    use std::error;
    // use std::signer;
    // use std::string;
    // use aptos_framework::account;
    // use aptos_std::event;

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

//:!:>resource
    struct PauseOrNot has key {
        paused: bool
    }

    const EACCOUNT_NOT_FOUND: u64 = 0;
    const NOT_INITIALIZED: u64 = 1;
    const EINSUFFICIENT_BALANCE: u64 = 2;

    // pause
    // unpause
    // initialize vault creation sys with admin only rights
    // allow users to deposit a token, track user address and token value
    // allows users to withdraw a token, track user address bal

    public entry fun pause(addr: address) acquires PauseOrNot {
        assert!(exists<PauseOrNot>(addr), error::not_found(NOT_INITIALIZED));
        borrow_global_mut<PauseOrNot>(addr).paused = true
    }

    public entry fun unpause(addr: address) acquires PauseOrNot {
        assert!(exists<PauseOrNot>(addr), error::not_found(NOT_INITIALIZED));
        borrow_global_mut<PauseOrNot>(addr).paused = false
    }
    public entry fun check_pause_status(addr: address): bool acquires PauseOrNot {
        assert!(exists<PauseOrNot>(addr), error::not_found(NOT_INITIALIZED));
        *&borrow_global<PauseOrNot>(addr).paused
    }

    public entry fun init(account: signer) {
        // let admin_addr = signer::address_of(&account);
        
        move_to(&account, PauseOrNot {
            paused: true,
        })
    }

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
