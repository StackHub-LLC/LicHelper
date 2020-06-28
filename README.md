# SkyArc License Helper for StackHub Products

A helper class that finds valid StackHub licences on SkyArc systems. Note that the `StackHubLic` class and extension disabling is only available in SkySpark 3.0.12 or later.

Copy and paste the Fantom class below into your SkyArc project.

Repeated calls to the `findXXX()` methods whittle down the number of valid licences until one is left. The remaining licence may be retrieved with `get()`.

A `LicErr` is thrown should no licence match the given criteria. This may be caught to disable the containing SkyArc extension.

licence validation may be performed during the extension `onStart()` event. Typical usage would be:

	using skyarcd::Ext
	using skyarcd::ExtMeta
	using haystack::Ref
	using stackhub::StackHubLic
	
	@ExtMeta { name = "acmeExt" }
	const class AcmeExt : Ext {
	
		** Validate the licence file.
		override Void onStart() {
			try {
				lic := LicHelper(sys)
					.findVendor(Ref("87654321-87654321", "Acme"))
					.findPackage(Depend("acmeExt 1.0"))
					.findProduct(Ref("12345678-12345678", "AcmeExt"))
					.findValid.get
	
				cap := LicHelper.parseCapacity(lic)
	
				// ... validate licence capacity here ...
	
				log.info("${lic.product.dis} licensed to ${lic.licensee} --> okay")

			} catch (LicErr err) {
				// if a valid licence can not be found, disable this extension
				StackHubLic.extToFault(this, err.msg)
			}
		}
	}

Note `findVendor()` should be called with your StackHub Vendor ID available from the [My Products](https://stackhub.org/my/products/) page.

`findProduct()` should be called with your StackHub Product ID, available from the [My Product](https://stackhub.org/my/products/) edit pages. 

`findPackage()` should probably be called with the details of the current pod:

	findPackage(Depend("${typeof.pod.name} ${typeof.pod.version}"))

Contact [StackHub](https://stackhub.org/) should you require help with Fantom code.
