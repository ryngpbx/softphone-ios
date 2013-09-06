//
//  pjsua_app.h
//  Jazinga Softphone
//
//  Created by John Mah on 12-06-21.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#ifndef Jazinga_Softphone_pjsua_app_h
#define Jazinga_Softphone_pjsua_app_h

#define MAX_AVI             4

//#define STEREO_DEMO
//#define TRANSPORT_ADAPTER_SAMPLE
//#define HAVE_MULTIPART_TEST

/* Ringtones		    US	       UK  */
#define RINGBACK_FREQ1	    440	    /* 400 */
#define RINGBACK_FREQ2	    480	    /* 450 */
#define RINGBACK_ON         2000    /* 400 */
#define RINGBACK_OFF	    4000    /* 200 */
#define RINGBACK_CNT	    1	    /* 2   */
#define RINGBACK_INTERVAL   4000    /* 2000 */

#define RING_FREQ1          800
#define RING_FREQ2          640
#define RING_ON             200
#define RING_OFF            100
#define RING_CNT            3
#define RING_INTERVAL	    3000

/* Call specific data */
struct call_data
{
    pj_timer_entry	    timer;
    pj_bool_t		    ringback_on;
    pj_bool_t		    ring_on;
};

/* Video settings */
struct app_vid
{
    unsigned		    vid_cnt;
    int			    vcapture_dev;
    int			    vrender_dev;
    pj_bool_t		    in_auto_show;
    pj_bool_t		    out_auto_transmit;
};

/* Pjsua application data */
struct app_config
{
    pjsua_config	    cfg;
    pjsua_logging_config    log_cfg;
    pjsua_media_config	    media_cfg;
    pj_bool_t		    no_refersub;
    pj_bool_t		    ipv6;
    pj_bool_t		    enable_qos;
    pj_bool_t		    no_tcp;
    pj_bool_t		    no_udp;
    pj_bool_t		    use_tls;
    pjsua_transport_config  udp_cfg;
    pjsua_transport_config  rtp_cfg;
    pjsip_redirect_op	    redir_op;
    
    unsigned		    acc_cnt;
    pjsua_acc_config	    acc_cfg[PJSUA_MAX_ACC];
    
    unsigned		    buddy_cnt;
    pjsua_buddy_config	    buddy_cfg[PJSUA_MAX_BUDDIES];
    
    struct call_data	    call_data[PJSUA_MAX_CALLS];
    
    pj_pool_t		   *pool;
    /* Compatibility with older pjsua */
    
    unsigned		    codec_cnt;
    pj_str_t		    codec_arg[32];
    unsigned		    codec_dis_cnt;
    pj_str_t                codec_dis[32];
    pj_bool_t		    null_audio;
    unsigned		    wav_count;
    pj_str_t		    wav_files[32];
    unsigned		    tone_count;
    pjmedia_tone_desc	    tones[32];
    pjsua_conf_port_id	    tone_slots[32];
    pjsua_player_id	    wav_id;
    pjsua_conf_port_id	    wav_port;
    pj_bool_t		    auto_play;
    pj_bool_t		    auto_play_hangup;
    pj_timer_entry	    auto_hangup_timer;
    pj_bool_t		    auto_loop;
    pj_bool_t		    auto_conf;
    pj_str_t		    rec_file;
    pj_bool_t		    auto_rec;
    pjsua_recorder_id	    rec_id;
    pjsua_conf_port_id	    rec_port;
    unsigned		    auto_answer;
    unsigned		    duration;
    
#ifdef STEREO_DEMO
    pjmedia_snd_port	   *snd;
    pjmedia_port	   *sc, *sc_ch1;
    pjsua_conf_port_id	    sc_ch1_slot;
#endif
    
    float		    mic_level,
    speaker_level;
    
    int			    capture_dev, playback_dev;
    unsigned		    capture_lat, playback_lat;
    
    pj_bool_t		    no_tones;
    int			    ringback_slot;
    int			    ringback_cnt;
    pjmedia_port	   *ringback_port;
    int			    ring_slot;
    int			    ring_cnt;
    pjmedia_port	   *ring_port;
    
    struct app_vid	    vid;
    unsigned		    aud_cnt;
    
    /* AVI to play */
    unsigned                avi_cnt;
    struct {
        pj_str_t		path;
        pjmedia_vid_dev_index	dev_id;
        pjsua_conf_port_id	slot;
    } avi[MAX_AVI];
    pj_bool_t               avi_auto_play;
    int			    avi_def_idx;
    
} app_config;

void ringback_start(pjsua_call_id call_id);
void ring_start(pjsua_call_id call_id);
void ring_stop(pjsua_call_id call_id);

void log_call_dump(int call_id);

void call_timeout_callback(pj_timer_heap_t *timer_heap,
                           struct pj_timer_entry *entry);
void hangup_timeout_callback(pj_timer_heap_t *timer_heap,
                             struct pj_timer_entry *entry);

pj_status_t on_playfile_done(pjmedia_port *port, void *usr_data);

void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id,
                      pjsip_rx_data *rdata);
void on_call_tsx_state(pjsua_call_id call_id,
                       pjsip_transaction *tsx,
                       pjsip_event *e);
void on_call_generic_media_state(pjsua_call_info *ci, unsigned mi,
                                 pj_bool_t *has_error);
void on_call_audio_state(pjsua_call_info *ci, unsigned mi,
                         pj_bool_t *has_error);
void on_call_video_state(pjsua_call_info *ci, unsigned mi,
                         pj_bool_t *has_error);
void on_call_media_state(pjsua_call_id call_id);
void call_on_dtmf_callback(pjsua_call_id call_id, int dtmf);
pjsip_redirect_op call_on_redirected(pjsua_call_id call_id, 
                                     const pjsip_uri *target,
                                     const pjsip_event *e);
void on_reg_state(pjsua_acc_id acc_id);
void on_incoming_subscribe(pjsua_acc_id acc_id,
                           pjsua_srv_pres *srv_pres,
                           pjsua_buddy_id buddy_id,
                           const pj_str_t *from,
                           pjsip_rx_data *rdata,
                           pjsip_status_code *code,
                           pj_str_t *reason,
                           pjsua_msg_data *msg_data);
void on_buddy_state(pjsua_buddy_id buddy_id);
void on_buddy_evsub_state(pjsua_buddy_id buddy_id,
                          pjsip_evsub *sub,
                          pjsip_event *event);
void on_pager(pjsua_call_id call_id, const pj_str_t *from, 
              const pj_str_t *to, const pj_str_t *contact,
              const pj_str_t *mime_type, const pj_str_t *text);
void on_typing(pjsua_call_id call_id, const pj_str_t *from,
               const pj_str_t *to, const pj_str_t *contact,
               pj_bool_t is_typing);
void on_call_transfer_status(pjsua_call_id call_id,
                             int status_code,
                             const pj_str_t *status_text,
                             pj_bool_t final,
                             pj_bool_t *p_cont);
void on_call_replaced(pjsua_call_id old_call_id,
                      pjsua_call_id new_call_id);
void on_nat_detect(const pj_stun_nat_detect_result *res);
void on_mwi_info(pjsua_acc_id acc_id, pjsua_mwi_info *mwi_info);
void on_transport_state(pjsip_transport *tp, 
                        pjsip_transport_state state,
                        const pjsip_transport_state_info *info);
void on_ice_transport_error(int index, pj_ice_strans_op op,
                            pj_status_t status, void *param);
pj_status_t on_snd_dev_operation(int operation);
void on_call_media_event(pjsua_call_id call_id,
                         unsigned med_idx,
                         pjmedia_event *event);

pj_status_t create_ipv6_media_transports(void);
pj_status_t app_destroy(void);
void default_config(struct app_config *cfg);

pj_status_t parse_args(int argc, char *argv[],
                       struct app_config *cfg,
                       pj_str_t *uri_to_call);
pj_bool_t default_mod_on_rx_request(pjsip_rx_data *rdata);

#endif
