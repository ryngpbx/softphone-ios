//
//  This class was created by Nonnus,
//  who graciously decided to share it with the CocoaHTTPServer community.
//

#import "localhostAdresses.h"

#import <ifaddrs.h>
#import <netinet/in.h>
#import <sys/socket.h>

@implementation localhostAdresses

+ (void)list
{
    @autoreleasepool {
	
	NSMutableDictionary* result = [NSMutableDictionary dictionary];
	struct ifaddrs*	addrs;
	BOOL success = (getifaddrs(&addrs) == 0);
	if (success) 
	{
		const struct ifaddrs* cursor = addrs;
		while (cursor != NULL) 
		{
			NSMutableString* ip;
			if (cursor->ifa_addr->sa_family == AF_INET) 
			{
				const struct sockaddr_in* dlAddr = (const struct sockaddr_in*)cursor->ifa_addr;
				const uint8_t* base = (const uint8_t*)&dlAddr->sin_addr;
				ip = [NSMutableString new];
				for (int i = 0; i < 4; i++) 
				{
					if (i != 0) 
						[ip appendFormat:@"."];
					[ip appendFormat:@"%d", base[i]];
				}
				[result setObject:(NSString*)ip forKey:[NSString stringWithFormat:@"%s", cursor->ifa_name]];
			}
			cursor = cursor->ifa_next;
		}
		freeifaddrs(addrs);
	}
	
	//Get IP address.  
	/*
	NSString *netIP;
	NSURLResponse* resp;
	NSError *error;
	
	NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://whatismyip.org"] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:2.0];
	
	NSData* data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&error];
	netIP = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if(netIP != nil && netIP.length > 0 && ![netIP isKindOfClass:[NSNull class]]){
		[result setObject:netIP forKey:@"www"];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"LocalhostAdressesResolved" object:result];
	} else {
		req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.myglobalip.com/myip"] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:2.0];
		data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&error];
		netIP = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		if(netIP != nil && netIP.length > 0 && ![netIP isKindOfClass:[NSNull class]]){
			[result setObject:netIP forKey:@"www"];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"LocalhostAdressesResolved" object:result];
		} else {
			req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://icanhazip.com/"] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:2.0];
			data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&error];
			netIP = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			
			//Need to notify with netIP even if it is nil.  If not, application will hang.
			[result setObject:netIP forKey:@"www"];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"LocalhostAdressesResolved" object:result];
		}
	}
	*/

	[[NSNotificationCenter defaultCenter] postNotificationName:@"LocalhostAdressesResolved" object:result];
    }
}

@end
