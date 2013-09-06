
//
//  SIPWrapper.m
//  Jazinga Softphone
//
//  Created by John Mah on 12-07-04.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "SIPWrapper.h"
#import "SIPAccountManager.h"
#import "AppDelegate.h"
#import "pjsua_app.h"

#define THIS_FILE   "SIPWrapper.m"
#define NO_LIMIT	(int)0x7FFFFFFF

extern pjsua_call_id current_call;
extern pj_log_func *log_cb;

pjsua_transport_id tcp_transport_id = -1;

/* The module instance. */
static pjsip_module mod_default_handler = 
{
    NULL, NULL,				/* prev, next.		*/
    { "mod-default-handler", 19 },	/* Name.		*/
    -1,					/* Id			*/
    PJSIP_MOD_PRIORITY_APPLICATION+99,	/* Priority	        */
    NULL,				/* load()		*/
    NULL,				/* start()		*/
    NULL,				/* stop()		*/
    NULL,				/* unload()		*/
    &default_mod_on_rx_request,		/* on_rx_request()	*/
    NULL,				/* on_rx_response()	*/
    NULL,				/* on_tx_request.	*/
    NULL,				/* on_tx_response()	*/
    NULL,				/* on_tsx_state()	*/
    
};

@implementation SIPWrapper

@end

/*
 * Handler when invite state has changed.
 */
void jazinga_on_call_state(pjsua_call_id call_id, pjsip_event *e)
{
    pjsua_call_info call_info;
    
    PJ_UNUSED_ARG(e);
    
    pjsua_call_get_info(call_id, &call_info);
    
    if (call_info.state == PJSIP_INV_STATE_DISCONNECTED) {
        
        /* Stop all ringback for this call */
        ring_stop(call_id);

        // hack to force sound device close after a bad SIP call
        pjsua_conf_disconnect(0, 0);
        
        /* Cancel duration timer, if any */
        if (app_config.call_data[call_id].timer.id != PJSUA_INVALID_ID) {
            struct call_data *cd = &app_config.call_data[call_id];
            pjsip_endpoint *endpt = pjsua_get_pjsip_endpt();
            
            cd->timer.id = PJSUA_INVALID_ID;
            pjsip_endpt_cancel_timer(endpt, &cd->timer);
        }
        
        // remove tone generator
        call_deinit_tonegen(call_id);
        
        // dismiss the UI screens for incoming/outgoing calls
        [[AppDelegate sharedAppDelegate] cancel:call_id];

        /* Rewind play file when hangup automatically, 
         * since file is not looped
         */
        if (app_config.auto_play_hangup)
            pjsua_player_set_pos(app_config.wav_id, 0);
        
        PJ_LOG(3,(THIS_FILE, "Call %d is DISCONNECTED [reason=%d (%s)]", 
                  call_id,
                  call_info.last_status,
                  call_info.last_status_text.ptr));

        /*
         if (call_id == current_call) {
         find_next_call();
         }
         */
        
        /* Dump media state upon disconnected */
        if (1) {
            PJ_LOG(5,(THIS_FILE, 
                      "Call %d disconnected, dumping media stats..", 
                      call_id));
            log_call_dump(call_id);
        }
    } else if (call_info.state == PJSIP_INV_STATE_CALLING) {
        // display call screen
        [[AppDelegate sharedAppDelegate] present:call_id];
    } else if (call_info.state == PJSIP_INV_STATE_CONFIRMED) {
        if (app_config.duration != NO_LIMIT) {
            /* Schedule timer to hangup call after the specified duration */
            struct call_data *cd = &app_config.call_data[call_id];
            pjsip_endpoint *endpt = pjsua_get_pjsip_endpt();
            pj_time_val delay;
            
            cd->timer.id = call_id;
            delay.sec = app_config.duration;
            delay.msec = 0;
            pjsip_endpt_schedule_timer(endpt, &cd->timer, &delay);
        }

        // create a tone generator for DTMF
        call_init_tonegen(call_id);
        
        // make current call active
        [[AppDelegate sharedAppDelegate] active:call_id];
    } else {        
        if (call_info.state == PJSIP_INV_STATE_EARLY) {
            int code;
            pj_str_t reason;
            pjsip_msg *msg;
            
            /* This can only occur because of TX or RX message */
            pj_assert(e->type == PJSIP_EVENT_TSX_STATE);
            
            if (e->body.tsx_state.type == PJSIP_EVENT_RX_MSG) {
                msg = e->body.tsx_state.src.rdata->msg_info.msg;
            } else {
                msg = e->body.tsx_state.src.tdata->msg;
            }
            
            code = msg->line.status.code;
            reason = msg->line.status.reason;
            
            /* Start ringback for 180 for UAC unless there's SDP in 180 */
            if (call_info.role==PJSIP_ROLE_UAC && code==180 && 
                msg->body == NULL && 
                call_info.media_status==PJSUA_CALL_MEDIA_NONE) 
            {
                ringback_start(call_id);
            }
            
            PJ_LOG(3,(THIS_FILE, "Call %d state changed to %s (%d %.*s)", 
                      call_id, call_info.state_text.ptr,
                      code, (int)reason.slen, reason.ptr));
        } else {
            PJ_LOG(3,(THIS_FILE, "Call %d state changed to %s", 
                      call_id,
                      call_info.state_text.ptr));
        }
        
        if (current_call==PJSUA_INVALID_ID)
            current_call = call_id;
    }
}

struct my_call_data *call_init_tonegen(pjsua_call_id call_id)
{
    pj_pool_t *pool;
    struct my_call_data *cd;
    pjsua_call_info ci;
    
    pool = pjsua_pool_create("mycall", 512, 512);
    cd = PJ_POOL_ZALLOC_T(pool, struct my_call_data);
    cd->pool = pool;
    
    pjmedia_tonegen_create(cd->pool, 8000, 1, 160, 16, 0, &cd->tonegen);
    pjsua_conf_add_port(cd->pool, cd->tonegen, &cd->toneslot);
    
    pjsua_call_get_info(call_id, &ci);
    pjsua_conf_connect(cd->toneslot, 0);
    // pjsua_conf_connect(cd->toneslot, ci.conf_slot);
    
    pjsua_call_set_user_data(call_id, (void*) cd);
    
    return cd;
}

void call_deinit_tonegen(pjsua_call_id call_id)
{
    struct my_call_data *cd;
    
    cd = (struct my_call_data*) pjsua_call_get_user_data(call_id);
    if (!cd)
        return;
    
    pjsua_conf_remove_port(cd->toneslot);
    pjmedia_port_destroy(cd->tonegen);
    pj_pool_release(cd->pool);
    
    pjsua_call_set_user_data(call_id, NULL);
}

/*
 * Callback on media state changed event.
 * The action may connect the call to sound device, to file, or
 * to loop the call.
 */
void jazinga_on_call_media_state(pjsua_call_id call_id)
{
    pjsua_call_info call_info;
    unsigned mi;
    pj_bool_t has_error = PJ_FALSE;
    
    pjsua_call_get_info(call_id, &call_info);
    
    for (mi=0; mi<call_info.media_cnt; ++mi) {
        on_call_generic_media_state(&call_info, mi, &has_error);
        
        switch (call_info.media[mi].type) {
            case PJMEDIA_TYPE_AUDIO:
                jazinga_on_call_audio_state(&call_info, mi, &has_error);
                break;
            case PJMEDIA_TYPE_VIDEO:
                on_call_video_state(&call_info, mi, &has_error);
                break;
            default:
                /* Make gcc happy about enum not handled by switch/case */
                break;
        }
    }
    
    if (has_error) {
        pj_str_t reason = pj_str("Media failed");
        pjsua_call_hangup(call_id, 500, &reason, NULL);
    }
    
#if PJSUA_HAS_VIDEO
    /* Check if remote has just tried to enable video */
    if (call_info.rem_offerer && call_info.rem_vid_cnt)
    {
        int vid_idx;
        
        /* Check if there is active video */
        vid_idx = pjsua_call_get_vid_stream_idx(call_id);
        if (vid_idx == -1 || call_info.media[vid_idx].dir == PJMEDIA_DIR_NONE) {
            PJ_LOG(3,(THIS_FILE,
                      "Just rejected incoming video offer on call %d, "
                      "use \"vid call enable %d\" or \"vid call add\" to enable video!",
                      call_id, vid_idx));
        }
    }
#endif
}

/* Process audio media state. "mi" is the media index. */
void jazinga_on_call_audio_state(pjsua_call_info *ci, unsigned mi,
                                pj_bool_t *has_error)
{
    PJ_UNUSED_ARG(has_error);
    
    /* Stop ringback */
    ring_stop(ci->id);
    
    if (ci->media[mi].status == PJSUA_CALL_MEDIA_ACTIVE 
        || ci->media[mi].status == PJSUA_CALL_MEDIA_LOCAL_HOLD) {
        [[AppDelegate sharedAppDelegate] hold:ci->id];
    }

    /* Connect ports appropriately when media status is ACTIVE or REMOTE HOLD,
     * otherwise we should NOT connect the ports.
     */
    if (ci->media[mi].status == PJSUA_CALL_MEDIA_ACTIVE ||
        ci->media[mi].status == PJSUA_CALL_MEDIA_REMOTE_HOLD)
    {
        pj_bool_t connect_sound = PJ_TRUE;
        pj_bool_t disconnect_mic = PJ_FALSE;
        pjsua_conf_port_id call_conf_slot;
        
        call_conf_slot = ci->media[mi].stream.aud.conf_slot;
        
        /* Loopback sound, if desired */
        if (app_config.auto_loop) {
            pjsua_conf_connect(call_conf_slot, call_conf_slot);
            connect_sound = PJ_FALSE;
        }
        
        /* Automatically record conversation, if desired */
        if (app_config.auto_rec && app_config.rec_port != PJSUA_INVALID_ID) {
            pjsua_conf_connect(call_conf_slot, app_config.rec_port);
        }
        
        /* Stream a file, if desired */
        if ((app_config.auto_play || app_config.auto_play_hangup) && 
            app_config.wav_port != PJSUA_INVALID_ID)
        {
            pjsua_conf_connect(app_config.wav_port, call_conf_slot);
            connect_sound = PJ_FALSE;
        }
        
        /* Stream AVI, if desired */
        if (app_config.avi_auto_play &&
            app_config.avi_def_idx != PJSUA_INVALID_ID &&
            app_config.avi[app_config.avi_def_idx].slot != PJSUA_INVALID_ID)
        {
            pjsua_conf_connect(app_config.avi[app_config.avi_def_idx].slot,
                               call_conf_slot);
            disconnect_mic = PJ_TRUE;
        }
        
        /* Put call in conference with other calls, if desired */
        if (app_config.auto_conf) {
            pjsua_call_id call_ids[PJSUA_MAX_CALLS];
            unsigned call_cnt=PJ_ARRAY_SIZE(call_ids);
            unsigned i;
            
            /* Get all calls, and establish media connection between
             * this call and other calls.
             */
            pjsua_enum_calls(call_ids, &call_cnt);
            
            for (i=0; i<call_cnt; ++i) {
                if (call_ids[i] == ci->id)
                    continue;
                
                if (!pjsua_call_has_media(call_ids[i]))
                    continue;
                
                pjsua_conf_connect(call_conf_slot,
                                   pjsua_call_get_conf_port(call_ids[i]));
                pjsua_conf_connect(pjsua_call_get_conf_port(call_ids[i]),
                                   call_conf_slot);
                
                /* Automatically record conversation, if desired */
                if (app_config.auto_rec && app_config.rec_port != PJSUA_INVALID_ID) {
                    pjsua_conf_connect(pjsua_call_get_conf_port(call_ids[i]), 
                                       app_config.rec_port);
                }
                
            }
            
            /* Also connect call to local sound device */
            connect_sound = PJ_TRUE;
        }
        
        /* Otherwise connect to sound device */
        if (connect_sound) {
            pjsua_conf_connect(call_conf_slot, 0);
            if (!disconnect_mic)
                pjsua_conf_connect(0, call_conf_slot);
            
            /* Automatically record conversation, if desired */
            if (app_config.auto_rec && app_config.rec_port != PJSUA_INVALID_ID) {
                pjsua_conf_connect(call_conf_slot, app_config.rec_port);
                pjsua_conf_connect(0, app_config.rec_port);
            }
        }
    }
}

void jazinga_on_reg_started(pjsua_acc_id acc_id, pj_bool_t renew) {
    PJ_UNUSED_ARG(acc_id);
}

/*
 * Handler registration status has changed.
 */
void jazinga_on_reg_state(pjsua_acc_id acc_id)
{
    PJ_UNUSED_ARG(acc_id);
}

/*
 * Handler registration status has changed.
 */

static pjsua_acc_id the_acc_id = PJSUA_INVALID_ID;
static pjsip_transport *the_transport = NULL;

void jazinga_on_reg_state2(pjsua_acc_id acc_id, pjsua_reg_info *ri)
{
    PJ_UNUSED_ARG(acc_id);
    struct pjsip_regc_cbparam *rp = ri->cbparam;
    
    // check for failed registration, notify account manager to use fallback
    if (rp->code/100 == 2 && rp->expiration > 0 && rp->contact_cnt > 0) {
#ifdef NETWORK_SWITCH_OPTION_2
        /* Registration success */
        if (the_transport) {
            PJ_LOG(3,(THIS_FILE, "xxx: Releasing transport.."));
            pjsip_transport_dec_ref(the_transport);
            the_transport = NULL;
			the_acc_id = PJSUA_INVALID_ID;
        }
        /* Save transport instance so that we can close it later when
         * new IP address is detected.
         */
        PJ_LOG(3,(THIS_FILE, "xxx: Saving transport.."));
        the_transport = rp->rdata->tp_info.transport;
		the_acc_id = acc_id;
        pjsip_transport_add_ref(the_transport);
#endif

        [[SIPAccountManager sharedAccountManager] activeSuccessfulRegistration:acc_id];
    } else {
#ifdef NETWORK_SWITCH_OPTION_2
        // release transport instance reference
        if (the_transport) {
            PJ_LOG(3,(THIS_FILE, "xxx: Releasing transport.."));
            pjsip_transport_dec_ref(the_transport);
            the_transport = NULL;
			the_acc_id = PJSUA_INVALID_ID;
        }
#endif

        if (ri->cbparam->code < 200 || ri->cbparam->code >= 300) {
            [[SIPAccountManager sharedAccountManager] activeFailedRegistration:acc_id];
        }
    }
}

void ip_change()
{
    pj_status_t status;
    
    PJ_LOG(3,(THIS_FILE, "xxx: IP change.."));
    
    if (the_transport) {
        status = pjsip_transport_shutdown(the_transport);
        if (status != PJ_SUCCESS)
    	    PJ_PERROR(1,(THIS_FILE, status, "xxx: pjsip_transport_shutdown() error"));
        pjsip_transport_dec_ref(the_transport);
        the_transport = NULL;
    }
    
	if (the_acc_id != PJSUA_INVALID_ID) {
		status = pjsua_acc_set_registration(the_acc_id, PJ_FALSE);
		if (status != PJ_SUCCESS)
			PJ_PERROR(1,(THIS_FILE, status, "xxx: pjsua_acc_set_registration(0) error"));
	}
}

pj_status_t jazinga_init_pjsip() {
    pjsua_transport_id transport_id = -1;
    pjsua_transport_config tcp_cfg;
    pj_status_t status;
    
    // Must create pjsua before anything else!
    status = pjsua_create();
    if (status != PJ_SUCCESS) {
        pjsua_perror(THIS_FILE, "Error initializing pjsua", status);
        return status;
    }
    
    // create pool for application
    app_config.pool = pjsua_pool_create("pjsua-app", 1000, 1000);
    
    // Initialize configs with default settings.
    pjsua_config_default(&app_config.cfg);
    pjsua_logging_config_default(&app_config.log_cfg);
    pjsua_media_config_default(&app_config.media_cfg);
    
    /* Parse the arguments */
    /*
    pj_str_t uri_arg;
    status = parse_args(argc, argv, &app_config, &uri_arg);
    if (status != PJ_SUCCESS)
        return status;
    */
    
    /* Initialize default config */
    default_config(&app_config);

#ifdef USE_STUN
    app_config.cfg.stun_srv_cnt = 1;
    app_config.cfg.stun_srv[0] = pj_str("stun.jazinga.net");
#endif

    /* Initialize application callbacks */
    app_config.cfg.cb.on_call_state = &jazinga_on_call_state;
    app_config.cfg.cb.on_call_media_state = &jazinga_on_call_media_state;
    app_config.cfg.cb.on_incoming_call = &on_incoming_call;
    app_config.cfg.cb.on_call_tsx_state = &on_call_tsx_state;
    app_config.cfg.cb.on_dtmf_digit = &call_on_dtmf_callback;
    app_config.cfg.cb.on_call_redirected = &call_on_redirected;
    app_config.cfg.cb.on_reg_started = &jazinga_on_reg_started;
    //app_config.cfg.cb.on_reg_state = &jazinga_on_reg_state;
    app_config.cfg.cb.on_reg_state2 = &jazinga_on_reg_state2;
    app_config.cfg.cb.on_incoming_subscribe = &on_incoming_subscribe;
    app_config.cfg.cb.on_buddy_state = &on_buddy_state;
    app_config.cfg.cb.on_buddy_evsub_state = &on_buddy_evsub_state;
    app_config.cfg.cb.on_pager = &on_pager;
    app_config.cfg.cb.on_typing = &on_typing;
    app_config.cfg.cb.on_call_transfer_status = &on_call_transfer_status;
    app_config.cfg.cb.on_call_replaced = &on_call_replaced;
    app_config.cfg.cb.on_nat_detect = &on_nat_detect;
    app_config.cfg.cb.on_mwi_info = &on_mwi_info;
    app_config.cfg.cb.on_transport_state = &on_transport_state;
    app_config.cfg.cb.on_ice_transport_error = &on_ice_transport_error;
    app_config.cfg.cb.on_snd_dev_operation = &on_snd_dev_operation;
    app_config.cfg.cb.on_call_media_event = &on_call_media_event;
#ifdef TRANSPORT_ADAPTER_SAMPLE
    app_config.cfg.cb.on_create_media_transport = &on_create_media_transport;
#endif
    app_config.log_cfg.msg_logging = PJ_FALSE;
    app_config.log_cfg.cb = log_cb;
    
    // set sound device latency
    if (app_config.capture_lat > 0)
        app_config.media_cfg.snd_rec_latency = app_config.capture_lat;
    if (app_config.playback_lat)
        app_config.media_cfg.snd_play_latency = app_config.playback_lat;

    // Customize other settings (or initialize them from application specific
    app_config.auto_conf = PJ_TRUE;

    // initialize pjsua
    status = pjsua_init(&app_config.cfg, &app_config.log_cfg, &app_config.media_cfg);
    if (status != PJ_SUCCESS) {
        pjsua_perror(THIS_FILE, "Error initializing pjsua", status);
        return status;
    }

    /* Initialize our module to handle otherwise unhandled request */
    status = pjsip_endpt_register_module(pjsua_get_pjsip_endpt(),
                                         &mod_default_handler);
    if (status != PJ_SUCCESS)
        return status;
    
    // initialize calls data
    for (int i=0; i<PJ_ARRAY_SIZE(app_config.call_data); ++i) {
        app_config.call_data[i].timer.id = PJSUA_INVALID_ID;
        app_config.call_data[i].timer.cb = &call_timeout_callback;
    }
    
    // optionally registers WAV file
    for (int i=0; i<app_config.wav_count; ++i) {
        pjsua_player_id wav_id;
        unsigned play_options = 0;
        
        if (app_config.auto_play_hangup)
            play_options |= PJMEDIA_FILE_NO_LOOP;
        
        status = pjsua_player_create(&app_config.wav_files[i], play_options, 
                                     &wav_id);
        if (status != PJ_SUCCESS)
            goto on_error;
        
        if (app_config.wav_id == PJSUA_INVALID_ID) {
            app_config.wav_id = wav_id;
            app_config.wav_port = pjsua_player_get_conf_port(app_config.wav_id);
            if (app_config.auto_play_hangup) {
                pjmedia_port *port;
                
                pjsua_player_get_port(app_config.wav_id, &port);
                status = pjmedia_wav_player_set_eof_cb(port, NULL, 
                                                       &on_playfile_done);
                if (status != PJ_SUCCESS)
                    goto on_error;
                
                pj_timer_entry_init(&app_config.auto_hangup_timer, 0, NULL, 
                                    &hangup_timeout_callback);
            }
        }
    }
    
    // optionally registers tone players
    for (int i=0; i<app_config.tone_count; ++i) {
        pjmedia_port *tport;
        char name[80];
        pj_str_t label;
        pj_status_t status;
        
        pj_ansi_snprintf(name, sizeof(name), "tone-%d,%d",
                         app_config.tones[i].freq1, 
                         app_config.tones[i].freq2);
        label = pj_str(name);
        status = pjmedia_tonegen_create2(app_config.pool, &label,
                                         8000, 1, 160, 16, 
                                         PJMEDIA_TONEGEN_LOOP,  &tport);
        if (status != PJ_SUCCESS) {
            pjsua_perror(THIS_FILE, "Unable to create tone generator", status);
            goto on_error;
        }
        
        status = pjsua_conf_add_port(app_config.pool, tport, 
                                     &app_config.tone_slots[i]);
        pj_assert(status == PJ_SUCCESS);
        
        status = pjmedia_tonegen_play(tport, 1, &app_config.tones[i], 0);
        pj_assert(status == PJ_SUCCESS);
    }
    
    pj_memcpy(&tcp_cfg, &app_config.udp_cfg, sizeof(tcp_cfg));
    
    // create ringback tones
    if (app_config.no_tones == PJ_FALSE) {
        unsigned i, samples_per_frame;
        pjmedia_tone_desc tone[RING_CNT+RINGBACK_CNT];
        pj_str_t name;
        
        samples_per_frame = app_config.media_cfg.audio_frame_ptime * 
        app_config.media_cfg.clock_rate *
        app_config.media_cfg.channel_count / 1000;
        
        /* Ringback tone (call is ringing) */
        name = pj_str("ringback");
        status = pjmedia_tonegen_create2(app_config.pool, &name, 
                                         app_config.media_cfg.clock_rate,
                                         app_config.media_cfg.channel_count, 
                                         samples_per_frame,
                                         16, PJMEDIA_TONEGEN_LOOP, 
                                         &app_config.ringback_port);
        if (status != PJ_SUCCESS)
            goto on_error;
        
        pj_bzero(&tone, sizeof(tone));
        for (i=0; i<RINGBACK_CNT; ++i) {
            tone[i].freq1 = RINGBACK_FREQ1;
            tone[i].freq2 = RINGBACK_FREQ2;
            tone[i].on_msec = RINGBACK_ON;
            tone[i].off_msec = RINGBACK_OFF;
        }
        tone[RINGBACK_CNT-1].off_msec = RINGBACK_INTERVAL;
        
        pjmedia_tonegen_play(app_config.ringback_port, RINGBACK_CNT, tone,
                             PJMEDIA_TONEGEN_LOOP);
        
        
        status = pjsua_conf_add_port(app_config.pool, app_config.ringback_port,
                                     &app_config.ringback_slot);
        if (status != PJ_SUCCESS)
            goto on_error;
        
        /* Ring (to alert incoming call) */
        name = pj_str("ring");
        status = pjmedia_tonegen_create2(app_config.pool, &name, 
                                         app_config.media_cfg.clock_rate,
                                         app_config.media_cfg.channel_count, 
                                         samples_per_frame,
                                         16, PJMEDIA_TONEGEN_LOOP, 
                                         &app_config.ring_port);
        if (status != PJ_SUCCESS)
            goto on_error;
        
        for (i=0; i<RING_CNT; ++i) {
            tone[i].freq1 = RING_FREQ1;
            tone[i].freq2 = RING_FREQ2;
            tone[i].on_msec = RING_ON;
            tone[i].off_msec = RING_OFF;
        }
        tone[RING_CNT-1].off_msec = RING_INTERVAL;
        
        pjmedia_tonegen_play(app_config.ring_port, RING_CNT, 
                             tone, PJMEDIA_TONEGEN_LOOP);
        
        status = pjsua_conf_add_port(app_config.pool, app_config.ring_port,
                                     &app_config.ring_slot);
        if (status != PJ_SUCCESS)
            goto on_error;
    }
    
    // add UDP transport unless it's disabled
    if (!app_config.no_udp) {
        pjsip_transport_type_e type = PJSIP_TRANSPORT_UDP;
        
        status = pjsua_transport_create(type,
                                        &app_config.udp_cfg,
                                        &transport_id);
        if (status != PJ_SUCCESS)
            goto on_error;
        
        if (app_config.udp_cfg.port == 0) {
            pjsua_transport_info ti;
            pj_sockaddr_in *a;
            
            pjsua_transport_get_info(transport_id, &ti);
            a = (pj_sockaddr_in*)&ti.local_addr;
            
            tcp_cfg.port = pj_ntohs(a->sin_port);
        }
    }
    
    // add UDP IPv6 transport unless it's disabled
    if (!app_config.no_udp && app_config.ipv6) {
        pjsip_transport_type_e type = PJSIP_TRANSPORT_UDP6;
        pjsua_transport_config udp_cfg;
        
        udp_cfg = app_config.udp_cfg;
        if (udp_cfg.port == 0)
            udp_cfg.port = DEFAULT_SIP_PORT;
        else
            udp_cfg.port += 10;
        status = pjsua_transport_create(type,
                                        &udp_cfg,
                                        &transport_id);
        if (status != PJ_SUCCESS)
            goto on_error;
    }
    
    // add TCP transport unless it's disabled
    if (!app_config.no_tcp) {
        status = pjsua_transport_create(PJSIP_TRANSPORT_TCP,
                                        &tcp_cfg, 
                                        &transport_id);
        if (status != PJ_SUCCESS)
            goto on_error;
        
        tcp_transport_id = transport_id;
    }
    
    /* Optionally set codec orders */
    for (int i=0; i<app_config.codec_cnt; ++i) {
        pjsua_codec_set_priority(&app_config.codec_arg[i],
                                 (pj_uint8_t)(PJMEDIA_CODEC_PRIO_NORMAL+i+9));
#if PJSUA_HAS_VIDEO
        pjsua_vid_codec_set_priority(&app_config.codec_arg[i],
                                     (pj_uint8_t)(PJMEDIA_CODEC_PRIO_NORMAL+i+9));
#endif
    }
    
    /* Add RTP transports */
    if (app_config.ipv6)
        status = create_ipv6_media_transports();
#if DISABLED_FOR_TICKET_1185
    else
        status = pjsua_media_transports_create(&app_config.rtp_cfg);
#endif
    if (status != PJ_SUCCESS)
        goto on_error;
    
    if (app_config.capture_dev  != PJSUA_INVALID_ID ||
        app_config.playback_dev != PJSUA_INVALID_ID) {
        status = pjsua_set_snd_dev(app_config.capture_dev, 
                                   app_config.playback_dev);
        if (status != PJ_SUCCESS)
            goto on_error;
    }    
    
    return PJ_SUCCESS;
    
on_error:
    jazinga_destroy_pjsip();
    return status;
}

pj_status_t jazinga_destroy_pjsip(void)
{
    pj_status_t status;
    unsigned i;
    
#ifdef STEREO_DEMO
    if (app_config.snd) {
        pjmedia_snd_port_destroy(app_config.snd);
        app_config.snd = NULL;
    }
    if (app_config.sc_ch1) {
        pjsua_conf_remove_port(app_config.sc_ch1_slot);
        app_config.sc_ch1_slot = PJSUA_INVALID_ID;
        pjmedia_port_destroy(app_config.sc_ch1);
        app_config.sc_ch1 = NULL;
    }
    if (app_config.sc) {
        pjmedia_port_destroy(app_config.sc);
        app_config.sc = NULL;
    }
#endif
    
    /* Close avi devs and ports */
    for (i=0; i<app_config.avi_cnt; ++i) {
        if (app_config.avi[i].slot != PJSUA_INVALID_ID)
            pjsua_conf_remove_port(app_config.avi[i].slot);
#if PJMEDIA_HAS_VIDEO && PJMEDIA_VIDEO_DEV_HAS_AVI
        if (app_config.avi[i].dev_id != PJMEDIA_VID_INVALID_DEV)
            pjmedia_avi_dev_free(app_config.avi[i].dev_id);
#endif
    }
    
    /* Close ringback port */
    if (app_config.ringback_port &&
        app_config.ringback_slot != PJSUA_INVALID_ID)
    {
        pjsua_conf_remove_port(app_config.ringback_slot);
        app_config.ringback_slot = PJSUA_INVALID_ID;
        pjmedia_port_destroy(app_config.ringback_port);
        app_config.ringback_port = NULL;
    }
    
    /* Close ring port */
    if (app_config.ring_port && app_config.ring_slot != PJSUA_INVALID_ID) {
        pjsua_conf_remove_port(app_config.ring_slot);
        app_config.ring_slot = PJSUA_INVALID_ID;
        pjmedia_port_destroy(app_config.ring_port);
        app_config.ring_port = NULL;
    }
    
    /* Close tone generators */
    for (i=0; i<app_config.tone_count; ++i) {
        pjsua_conf_remove_port(app_config.tone_slots[i]);
    }
    
    if (app_config.pool) {
        pj_pool_release(app_config.pool);
        app_config.pool = NULL;
    }
    
    status = pjsua_destroy();
    
    pj_bzero(&app_config, sizeof(app_config));
    
    return status;
}

void jazinga_restart_pjsip(void) {
    // destroy the existing pjsip instance
    jazinga_destroy_pjsip();
    
    // create a new instance and restart pjsip
    jazinga_init_pjsip();
    pjsua_start();
}