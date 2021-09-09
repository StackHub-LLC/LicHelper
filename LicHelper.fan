using stackhub::StackHubLic
using haystack::Ref
using skyarcd::Sys

** A helper class that finds valid StackHub licences.
** 
** Repeated calls to the 'findXXX()' methods whittle down the number of valid licences until one is 
** left. The remaining licence may be retrieved with 'get()'.
** 
** A'LicErr' is thrown should no licence match the given criteria. This may be caught to disable 
** the containing SkyArc extension.
** 
** licence validation may be performed during the extension 'onStart()' event. Typical usage would be:
** 
** pre>
** using skyarcd::Ext
** using skyarcd::ExtMeta
** using haystack::Ref
** using stackhub::StackHubLic
** 
** @ExtMeta { name = "acmeExt" }
** const class AcmeExt : Ext {
**
**    ** Validate the licence file.
**    override Void onStart() {
**        try {
**            lic := LicHelper(sys)
**                .findVendor(Ref("87654321-87654321", "Acme"))
**                .findPackage(Depend("acmeExt 1.0"))
**                .findProduct(Ref("12345678-12345678", "AcmeExt"))
**                .findValid.get
** 
**            cap := LicHelper.parseCapacity(lic)
** 
**            // ... validate licence capacity here ...
**
**            log.info("${lic.product.dis} licensed to ${lic.licensee} --> okay")
**            
**        } catch (LicErr err) {
**            // if a valid licence can not be found, disable this extension
**            StackHubLic.extToFault(this, err.msg)
**        }
**    }
**}
** <pre
** 
** Note 'findVendor()' should be called with your StackHub Vendor ID available from the 
** [My Products]`https://stackhub.org/my/products/` page.
** 
** 'findProduct()' should be called with your StackHub Product ID, available from the
** [My Product]`https://stackhub.org/my/products/` edit pages. 
** 
** 'findPackage()' should probably be called with the details of the current pod:
** 
**   findPackage(Depend("${typeof.pod.name} ${typeof.pod.version}"))
** 
internal final class LicHelper {
	** StackHub licences.
	StackHubLic[] lics

	** Creates a helper with all available StackHub licences.
	new makeSys(Sys sys) {
		this.lics = StackHubLic.list(sys)
	}

	** Creates a helper with the given licences.
	new makeLics(StackHubLic[] lics) {
		this.lics = lics
	}

	** Finds all StackHub licences created by the given StackHub vendor ID.
	** Throws 'LicErr' if none are found and 'checked' is 'true'.
	** 
	** Note that the 'dis' part of the 'Ref' is ignored for matching purposes.
	This findVendor(Ref vendorRef, Bool checked := true) {
		whittleDown("Could not find licence for vendor: ${refDis(vendorRef)}", checked) { vendorRef == it.vendor }
	}

	** Finds all StackHub licences for the given product.
	** Throws 'LicErr' if none are found and 'checked' is 'true'.
	** 
	** Note that the 'dis' part of the 'Ref' is ignored for matching purposes.
	This findProduct(Ref productRef, Bool checked := true) {
		whittleDown("Could not find licence for product: ${refDis(productRef)}", checked) { productRef == it.product }
	}

	** Finds all StackHub licences that match *any* of the given products.
	** Throws 'LicErr' if none are found and 'checked' is 'true'.
	** 
	** Note that the 'dis' part of the 'Ref' is ignored for matching purposes.
	This findProducts(Ref[] productRefs, Bool checked := true) {
		whittleDown("Could not find licence for products: " + productRefs.join(", ") { refDis(it) }, checked) { productRefs.contains(it.product) }		
	}

	** Finds all StackHub licences that match the given package.
	** Throws 'LicErr' if none are found and 'checked' is 'true'.
	This findPackage(Depend pkg, Bool checked := true) {
		if (pkg.size != 1 || pkg.isPlus || pkg.isRange) 
			throw ArgErr("Package should have a simple version: $pkg")
		return whittleDown("Could not find licence for package: ${pkg}", checked) |StackHubLic lic->Bool| {
			deps := (Depend[]) lic.props.get("packages", "").split(';').exclude { it.isEmpty }.map { Depend(it) }
			return deps.any |dep| {
				dep.name == pkg.name && dep.match(pkg.version)
			}
		}
	}
	
	** Finds all valid StackHub licences (*valid* as deemed by SkySpark).
	** Throws 'LicErr' if none are found and 'checked' is 'true'.
	** 
	** For validity SkySpark checks the licence signature and expiry date.
	This findValid(Bool checked := true) {
		oldLics := lics.dup 
		whittleDown("Could not find valid licence file", false) { it.isValid }
		if (checked && lics.isEmpty) {
			lic := oldLics.first
			throw lic == null
				? LicErr("Could not find valid licence file", oldLics)
				: LicErr("Invalid licence - ${lic.err}", oldLics)
		}
		return this
	}
	
	** Finds all StackHub licences that match the given function.
	** Throws 'LicErr' (with 'errMsg') if none are found and 'checked' is 'true'.
	This findAll(Str errMsg, |StackHubLic->Bool| func, Bool checked := true) {
		whittleDown(errMsg, checked, func)
	}
	
	** Returns the first valid licence from 'lics'. Throws 'LicErr' if none found or if there are 
	** multiple valid licences.
	StackHubLic? get(Bool checked := true) {
		lics := this.lics.findAll { it.isValid }
		if (checked && lics.size > 1)
			throw LicErr("Found multiple valid licences", lics)
		if (checked && lics.size == 0)
			throw LicErr("Could not find valid licence", this.lics)
		return lics.first
	}
	
	** Creates a duplicate copy of this helper.
	This dup() {
		LicHelper(lics.dup)
	}
	
	** Whittles down 'lics' and throws 'LicErr' should it become empty and 'checked' is 'true'.
	This whittleDown(Str errMsg, Bool checked, |StackHubLic->Bool| f) {
		oldLics := lics.dup 
		lics = lics.findAll(f)
		if (checked && lics.isEmpty)
			throw LicErr(errMsg, oldLics)
		return this
	}

	** Parses the 'capacity' field of the given licence into a map of units to quantity.
	** Returns an empty map if the 'capacity' property is not found in the licence.
	static Str:Int parseCapacity(StackHubLic lic) {
		caps  := Str:Int[:]
		lic.props.get("capacity")?.split(';')?.each {
			caps[it.split[1]] = it.split[0].toInt
		}
		return caps
	}
	
	** Pretty prints a 'Ref' with its ID and optional 'dis'.
	private static Str refDis(Ref ref) {
		ref.id + (ref.disVal == null ? "" : " ${ref.disVal}")
	}
}

const class LicErr : Err {
	** The licences in error
	const StackHubLic[] lics
	
	** The first licence from 'lics'
	const StackHubLic?	lic
	
	new make(Str msg) : super(msg) {
		this.lics	= StackHubLic#.emptyList
	}

	new makeLics(Str msg, StackHubLic[] lics) : super.make(msg) {
		this.lics	= lics
		this.lic	= lics.first
	}	
}
