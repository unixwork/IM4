//
//  app.h
//  IM4
//
//  Created by Olaf Wintermann on 12.08.23.
//


#ifndef IM4_app_h
#define IM4_app_h

typedef void(*app_func)(void*);

void app_call_mainthread(app_func func, void *userdata);

void app_refresh_contactlist(void *xmpp);


#endif /* IM4_app_h */
