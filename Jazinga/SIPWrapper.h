//
//  SIPWrapper.h
//  Jazinga Softphone
//
//  Created by John Mah on 12-07-04.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include <pjsua-lib/pjsua.h>
#include "gui.h"
#include "pjsua_app.h"

@interface SIPWrapper : NSObject

@end

typedef struct my_call_data
{
    pj_pool_t          *pool;
    pjmedia_port       *tonegen;
    pjsua_conf_port_id  toneslot;
	void 				*notification;
} my_call_data;

pj_status_t jazinga_init_pjsip(void);
pj_status_t jazinga_destroy_pjsip(void);
void jazinga_restart_pjsip(void);

void jazinga_on_call_state(pjsua_call_id call_id, pjsip_event *e);
void jazinga_on_call_media_state(pjsua_call_id call_id);

void jazinga_on_call_generic_media_state(pjsua_call_info *ci, unsigned mi,
                                         pj_bool_t *has_error);
void jazinga_on_call_audio_state(pjsua_call_info *ci, unsigned mi,
                                 pj_bool_t *has_error);
void jazinga_on_call_video_state(pjsua_call_info *ci, unsigned mi,
                                 pj_bool_t *has_error);
void jazinga_on_reg_state(pjsua_acc_id acc_id);
void jazinga_on_reg_state2(pjsua_acc_id acc_id, pjsua_reg_info *ri);

void ip_change();

struct my_call_data *call_init_tonegen(pjsua_call_id call_id);
void call_deinit_tonegen(pjsua_call_id call_id);
