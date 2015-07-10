## Process this file with automake to produce Makefile.in

SED=/bin/sed
GREP=/bin/grep
CAT=/bin/cat
ECHO=/bin/echo
if DISABLE_STANDALONE
STANDALONE = no
else
STANDALONE = yes
endif

SUFFIXES = .pl .pm .sh

VPATH=$(top_srcdir) $(top_srcdir)/plugins-scripts $(top_srcdir)/plugins-scripts/t

GL_MODULES=\
  ../lib/Monitoring/GLPlugin.pm \
  ../lib/Monitoring/GLPlugin/SNMP.pm \
  ../lib/Monitoring/GLPlugin/UPNP.pm

libexec_SCRIPTS=check_rittal_health
EXTRA_MODULES=\
  Classes/Rittal/CMCII/Component/SensorSubsystem.pm \
  Classes/Rittal/CMCII/Component/UnitSubsystem.pm \
  Classes/Rittal/CMCII.pm \
  Classes/Rittal/CMCIII/Component/DeviceSubsystem.pm \
  Classes/Rittal/CMCIII/Component/MessageSubsystem.pm \
  Classes/Rittal/CMCIII.pm \
  Classes/Rittal.pm \
  Classes/MibsAndOids.pm \
  Classes/Device.pm
EXTRA_DIST=check_rittal_health.pl $(EXTRA_MODULES) $(GL_MODULES)

CLEANFILES=$(libexec_SCRIPTS)

AM_INSTALL_PROGRAM_FLAGS=@INSTALL_OPTS@

.pm :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

.pl :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

.sh :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

$(libexec_SCRIPTS) : $(EXTRA_DIST)
	if [ -f ../../GLPlugin/lib/Monitoring/GLPlugin.pm ]; then cp -r ../../GLPlugin/lib ..; fi
	$(ECHO) "#! #PERL# -w" | $(AWK) -f ./subst > $@
	$(ECHO) "# nagios: -epn" >> $@
	$(ECHO) >> $@
	if [ "${STANDALONE}" == "yes" ]; then \
		$(ECHO) i am standalone; \
		for m in ${GL_MODULES}; do \
			$(SED) -e 's/^1;//g' < $$m | $(SED) -e '/^__END__/,$$d' | $(AWK) -f ./subst >> $@; \
		done \
	fi
	for m in ${EXTRA_MODULES}; do \
		$(SED) -e 's/^1;//g' < $$m | $(SED) -e '/^__END__/,$$d' | $(AWK) -f ./subst >> $@; \
	done
	$(ECHO) "package main;" >> $@
	$(CAT) $(libexec_SCRIPTS).pl | $(AWK) -f ./subst >> $@
	chmod +x $@

