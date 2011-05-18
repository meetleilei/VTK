package vtk;

import java.io.File;

/**
 * Enum used to load native library more easily. If you don't want to set the
 * specific environment variable you can provide the path of the directory that
 * contains the VTK library through a Java Property. Like in the following
 * command line:
 *
 * > java -cp vtk.jar -Dvtk.lib.dir=.../vtk-libs vtk.sample.SimpleVTK
 *
 * The directory .../vtk-libs must contain the so/dll/dylib + the jnilib files
 *
 * @author sebastien jourdain - sebastien.jourdain@kitware.com
 */
public enum vtkNativeLibrary {

    COMMON("vtkCommonJava"), //
    FILTERING("vtkFilteringJava"), //
    GEOVIS("vtkGeovisJava"), //
    GRAPHICS("vtkGraphicsJava"), //
    HYBRID("vtkHybridJava"), //
    IMAGING("vtkImagingJava"), //
    INFOVIS("vtkInfovisJava"), //
    IO("vtkIOJava"), //
    RENDERING("vtkRenderingJava"), //
    VIEWS("vtkViewsJava"), //
    VOLUME_RENDERING("vtkVolumeRenderingJava"), //
    WIDGETS("vtkWidgetsJava"), //
    CHARTS("vtkChartsJava");

    /**
     * Try to load all library
     *
     * @return true if all library have been successfully loaded
     */
    public static boolean LoadAllNativeLibraries() {
        boolean isEveryThingLoaded = true;
        for (vtkNativeLibrary lib : values()) {
            try {
                lib.LoadLibrary();
            } catch (UnsatisfiedLinkError e) {
                isEveryThingLoaded = false;
            }
        }

        return isEveryThingLoaded;
    }

    /**
     * Load the set of given library and trows runtime exception if any given
     * library failed in the loading process
     *
     * @param nativeLibraries
     */
    public static void LoadNativeLibraries(vtkNativeLibrary... nativeLibraries) {
        for (vtkNativeLibrary lib : nativeLibraries) {
            lib.LoadLibrary();
        }
    }

    private vtkNativeLibrary(String nativeLibraryName) {
        this.nativeLibraryName = nativeLibraryName;
        this.loaded = false;
    }

    /**
     * Load the library and throws runtime exception if the library failed in
     * the loading process
     */
    public void LoadLibrary() throws UnsatisfiedLinkError {
        if (!loaded) {
            if (System.getProperty("vtk.lib.dir") != null) {
                File dir = new File(System.getProperty("vtk.lib.dir"));
                patchJavaLibraryPath(dir.getAbsolutePath());
                File libPath = new File(dir, System.mapLibraryName(nativeLibraryName));
                if (libPath.exists()) {
                    try {
                        Runtime.getRuntime().load(libPath.getAbsolutePath());
                        loaded = true;
                        return;
                    } catch (UnsatisfiedLinkError e) {
                    }
                }
            }
            System.loadLibrary(nativeLibraryName);
        }
        loaded = true;
    }

    /**
     * @return true if the library has already been succefuly loaded
     */
    public boolean IsLoaded() {
        return loaded;
    }

    /**
     * @return the library name
     */
    public String GetLibraryName() {
        return nativeLibraryName;
    }

    private static void patchJavaLibraryPath(String vtkLibDir) {
        if (vtkLibDir != null) {
            String path_separator = System.getProperty("path.separator");
            String s = System.getProperty("java.library.path");
            if (!s.contains(vtkLibDir)) {
                s = s + path_separator + vtkLibDir;
                System.setProperty("java.library.path", s);
            }
        }
    }

    private String nativeLibraryName;
    private boolean loaded;
}
