#ifndef __UNITYPLUGIN_H__
#define __UNITYPLUGIN_H__

  #ifdef __cplusplus
  extern "C" {
  #endif
    
    typedef void (*SIMPLE_CALLBACK)();
    void reply_during_call(SIMPLE_CALLBACK callback);
    void set_recurring_reply(UInt32 hashCode, SIMPLE_CALLBACK callback);
    
    void poll_data(UInt32 hashCode, void **buffer, size_t *length);
    
    typedef void (*DATA_CALLBACK)(void *buffer, size_t length);
    void set_recurring_data_push(UInt32 hashCode, DATA_CALLBACK callback);

  #ifdef __cplusplus
  }
  #endif

#endif
