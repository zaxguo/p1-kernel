# to be included in usr/libXXX/Makefile. cf libminisdl/Makefile

$(TARGETLIB): $(OBJS)
	@rm -f $@
	@ar rc $@ $(OBJS)
	@ranlib $@

install: $(TARGETLIB) $(TARGETOBJS)
	@mkdir -p $(LIB_BUILD_PATH)
	cp -f $(TARGETLIB) $(TARGETOBJS) $(LIB_BUILD_PATH)