// Copyright 2018 Esri.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ArcGIS

class ViewshedLocationViewController: UIViewController, AGSGeoViewTouchDelegate, UIAdaptivePresentationControllerDelegate, ViewshedSettingsVCDelegate {

    @IBOutlet weak var sceneView: AGSSceneView!
    @IBOutlet weak var setObserverOnTapInstruction: UILabel!
    @IBOutlet weak var updateObserverOnDragInstruction: UILabel!
    
    private var viewshed: AGSLocationViewshed!
    private var analysisOverlay: AGSAnalysisOverlay!
    
    private var canMoveViewshed:Bool = false {
        didSet {
            setObserverOnTapInstruction.isHidden = canMoveViewshed
            updateObserverOnDragInstruction.isHidden = !canMoveViewshed
        }
    }
    
    private let ELEVATION_SERVICE_URL = URL(string: "https://scene.arcgis.com/arcgis/rest/services/BREST_DTM_1M/ImageServer")!
    private let SCENE_LAYER_URL = URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Buildings_Brest/SceneServer/layers/0")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // add the source code button item to the right of navigation bar
        (navigationItem.rightBarButtonItem as! SourceCodeBarButtonItem).filenames = ["ViewshedLocationViewController", "ViewshedSettingsVC"]
        
        // initialize the scene with an imagery basemap
        let scene = AGSScene(basemap: AGSBasemap.imagery())
        
        // assign the scene to the scene view
        sceneView.scene = scene
        
        // initialize the camera and set the viewpoint specified by the camera position
        let camera = AGSCamera(lookAt: AGSPoint(x: -4.50, y: 48.4, z: 100.0, spatialReference: AGSSpatialReference.wgs84()), distance: 200, heading: 20, pitch: 70, roll: 0)
        sceneView.setViewpointCamera(camera)
        
        // initialize the elevation source with the service URL and add it to the base surface of the scene
        let elevationSrc = AGSArcGISTiledElevationSource(url: ELEVATION_SERVICE_URL)
        scene.baseSurface?.elevationSources.append(elevationSrc)
        
        // initialize the scene layer with the scene layer URL and add it to the scene
        let buildings = AGSArcGISSceneLayer(url: SCENE_LAYER_URL)
        scene.operationalLayers.add(buildings)
        
        // initialize a viewshed analysis object with arbitrary location (the location will be defined by the user), heading, pitch, view angles, and distance range (in meters) from which visibility is calculated from the observer location
        viewshed = AGSLocationViewshed(location: AGSPoint(x: 0.0, y: 0.0, z: 0.0, spatialReference: AGSSpatialReference.wgs84()), heading: 20, pitch: 70, horizontalAngle: 45, verticalAngle: 90, minDistance: 50, maxDistance: 1000)
        
        // create an analysis overlay for the viewshed and to add it to the scene view
        analysisOverlay = AGSAnalysisOverlay()
        analysisOverlay.analyses.add(viewshed)
        sceneView.analysisOverlays.add(analysisOverlay)
        
        //set touch delegate on scene view as self
        sceneView.touchDelegate = self
    }
    
    // MARK: - UIAdaptivePresentationControllerDelegate
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        
        // for popover or non modal presentation
        return .none
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "settingsVCSegue" {
            
            // set viewshed settings view controller
            let viewshedSettingsVC = segue.destination as! ViewshedSettingsVC
            viewshedSettingsVC.delegate = self
            
            // pop over settings
            viewshedSettingsVC.presentationController?.delegate = self
            viewshedSettingsVC.popoverPresentationController?.passthroughViews = [sceneView]

            // preferred content size
            if traitCollection.horizontalSizeClass == .regular && traitCollection.verticalSizeClass == .regular {
                viewshedSettingsVC.preferredContentSize = CGSize(width: 340, height: 340)
            }
            else {
                viewshedSettingsVC.preferredContentSize = CGSize(width: 340, height: 240)
            }
        }
    }
    
    // MARK: - AGSGeoViewTouchDelegate
    
    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        canMoveViewshed = true
        // update the observer location from which the viewshed is calculated
        viewshed.location = mapPoint
    }
    
    func geoView(_ geoView: AGSGeoView, didTouchDownAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint, completion: @escaping (Bool) -> Void) {
        // tell the ArcGIS Runtime if we are going to handle interaction
        canMoveViewshed ? completion(true) : completion(false)
        
    }
    
    func geoView(_ geoView: AGSGeoView, didTouchDragToScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        // update the observer location from which the viewshed is calculated
        viewshed.location = mapPoint
    }
    
    
    // MARK: - ViewshedSettingsVCDelegate
    
    func viewshedSettingsVC(_ viewshedSettingsVC:ViewshedSettingsVC, didUpdateFrustumOutlineVisibility frustumOutlineVisibility:Bool) {
        viewshed.isFrustumOutlineVisible = frustumOutlineVisibility
    }
    
    func viewshedSettingsVC(_ viewshedSettingsVC:ViewshedSettingsVC, didUpdateAnalysisOverlayVisibility analysisOverlayVisibility:Bool) {
        analysisOverlay.isVisible = analysisOverlayVisibility
    }
    
    func viewshedSettingsVC(_ viewshedSettingsVC:ViewshedSettingsVC, didUpdateObstructedAreaColor obstructedAreaColor:UIColor) {
        // sets the color with which non-visible areas of all viewsheds will be rendered (default: red color). This setting is applied to all viewshed analyses in the view.
        AGSViewshed.setObstructedColor(obstructedAreaColor.withAlphaComponent(0.5))
    }
    
    func viewshedSettingsVC(_ viewshedSettingsVC:ViewshedSettingsVC, didUpdateVisibleAreaColor visibleAreaColor:UIColor) {
        // sets the color with which visible areas of all viewsheds will be rendered (default: green color). This setting is applied to all viewshed analyses in the view.
        AGSViewshed.setVisibleColor(visibleAreaColor.withAlphaComponent(0.5))
    }
    
    func viewshedSettingsVC(_ viewshedSettingsVC: ViewshedSettingsVC, didUpdateFrustumOutlineColor frustumOutlineColor: UIColor) {
        // sets the color used to render the frustum outline (default: blue color). This setting is applied to all viewshed analyses in the view.
        AGSViewshed.setFrustumOutlineColor(frustumOutlineColor)
    }
    
    func viewshedSettingsVC(_ viewshedSettingsVC:ViewshedSettingsVC, didUpdateHeading heading:Double) {
        viewshed.heading = heading
    }
    
    func viewshedSettingsVC(_ viewshedSettingsVC:ViewshedSettingsVC, didUpdatePitch pitch:Double) {
        viewshed.pitch = pitch
    }
    
    func viewshedSettingsVC(_ viewshedSettingsVC:ViewshedSettingsVC, didUpdateHorizontalAngle horizontalAngle:Double) {
        viewshed.horizontalAngle = horizontalAngle
    }
    
    func viewshedSettingsVC(_ viewshedSettingsVC:ViewshedSettingsVC, didUpdateVerticalAngle verticalAngle:Double) {
        viewshed.verticalAngle = verticalAngle
    }
    
    func viewshedSettingsVC(_ viewshedSettingsVC:ViewshedSettingsVC, didUpdateMinDistance minDistance:Double) {
        viewshed.minDistance = minDistance
    }
    
    func viewshedSettingsVC(_ viewshedSettingsVC:ViewshedSettingsVC, didUpdateMaxDistance maxDistance:Double) {
        viewshed.maxDistance = maxDistance
    }
    
}
