#import "OpenFreeMapController.h"

@implementation OpenFreeMapController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Baslangic pozisyonu (Istanbul - Taksim)
    NTMapPos *istanbul = [[NTMapPos alloc] initWithX:28.985 y:41.037];
    NTProjection *proj = [[self.mapView getOptions] getBaseProjection];
    [self.mapView setFocusPos:[proj fromWgs84:istanbul] durationSeconds:0];
    [self.mapView setZoom:16 durationSeconds:0];
    [self.mapView setTilt:30 durationSeconds:0];

    // TileJSON'dan dinamik tile URL'i cek
    [self fetchTileJSONAndSetupLayer];
}

- (void)fetchTileJSONAndSetupLayer {
    NSURL *tileJSONURL = [NSURL URLWithString:@"https://tiles.openfreemap.org/planet"];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithURL:tileJSONURL
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"TileJSON fetch error: %@", error);
                return;
            }

            NSError *jsonError;
            NSDictionary *tileJSON = [NSJSONSerialization JSONObjectWithData:data
                                                                     options:0
                                                                       error:&jsonError];
            if (jsonError) {
                NSLog(@"TileJSON parse error: %@", jsonError);
                return;
            }

            // tiles array'inden ilk URL'i al
            NSArray *tiles = tileJSON[@"tiles"];
            if (tiles.count == 0) {
                NSLog(@"No tile URLs found in TileJSON");
                return;
            }

            NSString *tileURLTemplate = tiles[0];
            NSLog(@"Using tile URL: %@", tileURLTemplate);

            // Main thread'de layer'i olustur
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setupLayerWithTileURL:tileURLTemplate];
            });
        }];

    [task resume];
}

- (void)setupLayerWithTileURL:(NSString *)tileURLTemplate {
    // 1. CARTO'nun built-in OpenMapTiles-uyumlu decoder'ini kullan
    NTMBVectorTileDecoder *decoder = (NTMBVectorTileDecoder *)[NTCartoVectorTileLayer createTileDecoderFromStyle:NT_CARTO_BASEMAP_STYLE_POSITRON];

    // 2. 3D binalari etkinlestir (1=2D, 2=3D)
    [decoder setStyleParameter:@"buildings" value:@"2"];

    // 3. OpenFreeMap tile data source (TileJSON'dan alinan versiyonlu URL)
    NTHTTPTileDataSource *dataSource = [[NTHTTPTileDataSource alloc]
        initWithMinZoom:0
        maxZoom:14
        baseURL:tileURLTemplate];

    // 4. Vector tile layer olustur
    NTVectorTileLayer *layer = [[NTVectorTileLayer alloc]
        initWithDataSource:dataSource
        decoder:decoder];

    // 5. Haritaya ekle
    [[self.mapView getLayers] add:layer];
}

@end
